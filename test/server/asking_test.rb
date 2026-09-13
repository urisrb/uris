require "test_helper"
require_relative "../support/fake_model_server"

class AskingTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  ASK = <<~GQL.freeze
    mutation($question: String!) {
      askCatalog(input: { question: $question }) { feed { id title } analysis { id status } }
    }
  GQL

  setup do
    SearchIndex.reset!

    @server = FakeModelServer.current
    @server.reset!.serves("qwen3:8b")
    ENV["URIS_INFERENCE_ORIGINS"] = @server.origin

    @tenant = Tenant.create!(subdomain: "ask-#{SecureRandom.hex(4)}", name: "Ask")

    Tenant.switch(@tenant) do
      Resource::OpenaiCompatible.create!(
        key: "ollama", details: { "base_url" => @server.base_url, "models" => { "agent" => "qwen3:8b" } }
      )
      @invoice = Feed.create!(type: Feed::NOTE, key: "Acme invoice", title: "Acme invoice")
      @other = Feed.create!(type: Feed::NOTE, key: "Beach photo", title: "Beach photo")
    end

    connect!(@tenant)
  end

  teardown { ENV.delete("URIS_INFERENCE_ORIGINS") }

  test "a question is kept as a note, answered from what a scout reported, and connected to what it cites" do
    scout("Find the Acme invoice's total") do
      @server.answer_tool_call("search", query: "invoice")
      @server.answer("The Acme invoice is for $4,200 [feed #{@invoice.id}].")
    end
    @server.answer("The Acme invoice is for $4,200 [feed #{@invoice.id}].")

    asked = ask("How much is the Acme invoice?")
    perform_enqueued_jobs(only: AnalyzeFeedJob)

    Tenant.switch(@tenant) do
      note = Feed.find(asked.dig("feed", "id"))
      analysis = Analysis.find(asked.dig("analysis", "id"))

      assert_equal Feed::NOTE, note.type
      assert_equal "feed", note.origin
      assert_equal "ask", analysis.cause
      assert_equal "done", analysis.status
      assert_match(/\$4,200/, analysis.step_result("text"))
      assert_equal [ @invoice.id ], note.connected.pluck(:id)
      assert_match(/lead : turn 1 : scout/, analysis.logs)
      assert_match(/scout 1 : turn 1 : search/, analysis.logs)
    end
  end

  test "the lead is turned back when it answers without sending a scout" do
    @server.answer("From memory, it is $4,200.")
    scout("Find the Acme invoice's total") { @server.answer("Nothing found.") }
    @server.answer("The scouts found nothing.")

    asked = ask("How much is the Acme invoice?")
    perform_enqueued_jobs(only: AnalyzeFeedJob)

    Tenant.switch(@tenant) do
      analysis = Analysis.find(asked.dig("analysis", "id"))

      assert_match(/lead : turn 1 : pressed : You have not sent a scout/, analysis.logs)
      assert_equal "The scouts found nothing.", analysis.step_result("text")
    end
  end

  test "several scouts sent in one turn each report back to the lead" do
    @server.answer_tool_calls([ [ "scout", { task: "Find the invoice" } ], [ "scout", { task: "Find the photo" } ] ])
    @server.answer("The invoice is [feed #{@invoice.id}].")
    @server.answer("The photo is [feed #{@other.id}].")
    @server.answer("Both are here: [feed #{@invoice.id}] and [feed #{@other.id}].")

    asked = ask("Where are the invoice and the photo?")
    perform_enqueued_jobs(only: AnalyzeFeedJob)

    Tenant.switch(@tenant) do
      analysis = Analysis.find(asked.dig("analysis", "id"))

      assert_equal 2, analysis.logs.scan(/\[✓\] : lead : turn 1 : scout/).size
      assert(%w[invoice photo].all? { |thing| analysis.turns.any? { |turn| turn["request"].to_s.include?("Find the #{thing}") } },
             "each scout was briefed with its own task")
      assert_equal [ @invoice.id, @other.id ].sort, Feed.find(asked.dig("feed", "id")).connected.pluck(:id).sort
    end
  end

  test "an answered question reads cleanly in the catalog, and asking it again asks rather than analyzes" do
    scout("Find the Acme invoice's total") { @server.answer("It is $4,200 [feed #{@invoice.id}].") }
    @server.answer("The Acme invoice is for $4,200 [feed #{@invoice.id}].")

    asked = ask("How much is the Acme invoice?")
    perform_enqueued_jobs(only: AnalyzeFeedJob)

    note = graphql("query($id: ID) { feed(id: $id) { asked summary analyzedAt } }", id: asked.dig("feed", "id"))["feed"]

    assert note["asked"]
    assert_equal "The Acme invoice is for $4,200.", note["summary"]
    assert note["analyzedAt"].present?

    again = graphql("mutation($id: ID!) { analyzeFeed(input: { id: $id }) { analysis { id } } }", id: asked.dig("feed", "id"))

    Tenant.switch(@tenant) { assert_equal "ask", Analysis.find(again.dig("analyzeFeed", "analysis", "id")).cause }
  end

  test "the question is never its own source, and scouts are told the web search when the tenant has one" do
    Tenant.switch(@tenant) do
      Resource::Search.create!(key: "exa", details: { "provider" => "exa" }, credentials: { "api_key" => "k" })
    end
    scout("Search the catalog for hn algolia") do
      @server.answer_tool_call("search", query: "hn algolia")
      @server.answer("Nothing in the catalog.")
      @server.answer("Nothing on the web either.")
    end
    @server.answer("Nothing in the catalog.")

    asked = ask("can you see hn algolia")
    perform_enqueued_jobs(only: AnalyzeFeedJob)

    Tenant.switch(@tenant) do
      analysis = Analysis.find(asked.dig("analysis", "id"))

      assert(analysis.turns.none? { |turn| turn["request"].to_s.include?(%("id":"#{asked.dig('feed', 'id')}")) },
             "the search a scout ran handed back the question it was answering")
    end

    assert(@server.prompts.any? { |prompt| prompt.include?("search the web") }, "the lead is told scouts can search the web")
    assert(@server.prompts.any? { |prompt| prompt.include?(%(key "exa")) }, "the scout is told the web search")
  end

  test "an answer is judged by ten judges, and the share who found it answered is its score" do
    scout("Find the Acme invoice's total") { @server.answer("It is $4,200 [feed #{@invoice.id}].") }
    @server.answer("The Acme invoice is for $4,200 [feed #{@invoice.id}].")
    7.times { @server.answer_json(answered: true, useful: true, why: "it says so") }
    3.times { @server.answer_json(answered: false, useful: false, why: "it does not") }

    asked = ask("How much is the Acme invoice?")
    perform_enqueued_jobs(only: AnalyzeFeedJob)

    feed = graphql("query($id: ID!) { feed(id: $id) { analyses { id verified useful } } }", id: asked.dig("feed", "id"))["feed"]

    assert_in_delta 0.7, feed["analyses"].first["verified"]
    assert_in_delta 0.7, feed["analyses"].first["useful"]
  end

  test "what a scout finds worth keeping becomes a note, connected to the question" do
    scout("Note where HN Search is hosted") do
      @server.answer_tool_call("feed", do: "create", type: "uris:note", title: "HN Search is hosted in Canada")
      @server.answer("Kept it.")
    end
    @server.answer("It is hosted in Canada.")

    asked = ask("where is hn search hosted?")
    perform_enqueued_jobs(only: AnalyzeFeedJob)

    Tenant.switch(@tenant) do
      note = Feed.find_by!(title: "HN Search is hosted in Canada")

      assert_equal Feed::NOTE, note.type
      assert_includes Feed.find(asked.dig("feed", "id")).connected.pluck(:id), note.id
    end
  end

  test "a scout changes only what the run made, whatever a page tells it to do" do
    scout("Tidy the catalog") do
      @server.answer_tool_call("feed", do: "note", id: @invoice.id.to_s, note: "wiped")
      @server.answer_tool_call("search", query: "invoice")
      @server.answer_tool_call("feed", do: "rename", id: @invoice.id.to_s, title: "wiped")
      @server.answer_tool_call("connect", a: @invoice.id.to_s, b: @other.id.to_s)
      @server.answer_tool_call("search", query: "invoice")
      @server.answer_tool_call("feed", do: "create", type: "uris:feed", title: "every hour", prompt: "spend")
      @server.answer("I could not.")
    end
    @server.answer("I could not.")

    ask("Connect the invoice to the beach photo")
    perform_enqueued_jobs(only: AnalyzeFeedJob)

    Tenant.switch(@tenant) do
      @invoice.reload

      assert_nil @invoice.note
      assert_equal "Acme invoice", @invoice.title
      assert_empty @invoice.connected
      assert_not Feed.exists?(title: "every hour")
    end
  end

  test "a scout can keep a page but cannot sync, export or snapshot through anything but the web" do
    Tenant.switch(@tenant) { @storage = Resource::Database.create!(key: "drop", name: "Drop") }
    scout("Keep example.com") do
      @server.answer_tool_call("resource", do: "sync", key: "drop")
      @server.answer_tool_call("resource", do: "snapshot", key: "drop", input: { url: "https://example.com" })
      @server.answer("I could not.")
    end
    @server.answer("I could not.")

    asked = ask("keep example.com")
    perform_enqueued_jobs(only: AnalyzeFeedJob)

    Tenant.switch(@tenant) do
      logs = Analysis.find(asked.dig("analysis", "id")).logs

      assert_match(/\[x\].*resource.*sync/, logs)
      assert_match(/\[x\].*resource.*snapshot.*does not keep pages/, logs)
      assert_equal 0, Run.where(resource: @storage).count
    end
  end

  test "a question with no model to answer it fails with the reason" do
    Tenant.switch(@tenant) { Resource.destroy_all }

    asked = ask("anything?")
    perform_enqueued_jobs(only: AnalyzeFeedJob)

    Tenant.switch(@tenant) do
      analysis = Analysis.find(asked.dig("analysis", "id"))

      assert_equal "failed", analysis.status
      assert_match(/agent role/, analysis.error)
    end
  end

  test "an empty question is refused" do
    body = post_ask("   ")

    assert_match(/needs something in it/, body.dig("errors", 0, "message"))
  end

  private

    def scout(task)
      @server.answer_tool_call("scout", task: task)
      yield
    end

    def ask(question)
      post_ask(question).dig("data", "askCatalog")
    end

    def post_ask(question)
      execute(ASK, question: question)
    end

    def graphql(query, **variables)
      execute(query, **variables)["data"]
    end

    def execute(query, **variables)
      token = issuer.mint(subdomain: @tenant.subdomain, scopes: Grant::SCOPES,
                          audience: "http://#{@tenant.subdomain}.uris.test/mcp")

      post "/graphql",
           params: { query: query, variables: variables.to_json },
           headers: { "HOST" => "#{@tenant.subdomain}.uris.test", "Authorization" => "Bearer #{token}" }

      response.parsed_body
    end
end
