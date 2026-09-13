require "test_helper"
require_relative "../../support/fake_model_server"

class VerifierTest < ActiveSupport::TestCase
  setup do
    @server = FakeModelServer.current
    @server.reset!.serves("qwen3:8b", "llama3.1:8b")
    ENV["URIS_INFERENCE_ORIGINS"] = @server.origin

    @tenant = Tenant.create!(subdomain: "verify-#{SecureRandom.hex(4)}", name: "Verify")
    @read = Agent::Dispatch::Result.new(name: "resource", arguments: { "do" => "get", "key" => "curl" },
                                        content: "HN Search is hosted in Beauharnois, Canada.", ok: true, error: nil)
    @refused = @read.with(content: "the secret refusal", ok: false)
  end

  teardown { ENV.delete("URIS_INFERENCE_ORIGINS") }

  def inference(models = { "agent" => "qwen3:8b", "smart" => "llama3.1:8b" })
    Resource::OpenaiCompatible.create!(key: "ollama", details: { "base_url" => @server.base_url, "models" => models })
  end

  test "the score is the share of judges who found it answered, each judging what the tools returned" do
    3.times { @server.answer_json(answered: true, why: "the page says so") }
    @server.answer_json(answered: false, why: "not supported")

    verdict = Tenant.switch(@tenant) do
      Verifier.new(inference: inference, runs: 4)
              .call(question: "where is hn search hosted?", answer: "Canada.", calls: [ @read, @refused ])
    end

    assert_in_delta 0.75, verdict.score
    assert_equal 4, verdict.runs
    assert_equal "not supported", verdict.votes.last["why"]
    assert(@server.prompts.all? { |prompt| prompt.include?("Beauharnois") })
    assert(@server.prompts.none? { |prompt| prompt.include?("the secret refusal") })
  end

  test "a judge that cannot answer abstains rather than counting against it" do
    @server.answer_json(answered: "true", why: "yes")

    verdict = Tenant.switch(@tenant) do
      Verifier.new(inference: inference, runs: 2).call(question: "q", answer: "a", calls: [])
    end

    assert_in_delta 1.0, verdict.score
    assert_equal 1, verdict.runs
  end

  test "it judges with the smart model when one is declared, and the agent's otherwise" do
    2.times { @server.answer_json(answered: true, why: "yes") }

    judged = Tenant.switch(@tenant) do
      analysis = Analysis.open!(feed: Feed.create!(type: Feed::NOTE, key: "q"), cause: "ask")
      smart = inference
      Verifier.new(analysis: analysis, runs: 1).call(question: "q", answer: "a", calls: [])

      smart.update!(details: smart.details.merge("models" => { "agent" => "qwen3:8b" }))
      Verifier.new(inference: smart, analysis: analysis, runs: 1).call(question: "q", answer: "a", calls: [])

      analysis.reload.turns.map { |turn| turn["model"] }
    end

    assert_equal [ "llama3.1:8b", "qwen3:8b" ], judged
  end

  test "an empty answer is not judged" do
    Tenant.switch(@tenant) do
      assert_nil Verifier.new(inference: inference, runs: 3).call(question: "q", answer: nil, calls: [])
    end

    assert_empty @server.prompts
  end
end
