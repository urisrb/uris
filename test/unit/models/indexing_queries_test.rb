require "test_helper"

class IndexingQueriesTest < ActiveSupport::TestCase
  setup do
    @tenant = Tenant.create!(subdomain: "idx-#{SecureRandom.hex(4)}", name: "Indexing")
  end

  def parent_with(children:)
    box = SecureRandom.hex(4)

    Tenant.switch(@tenant) do
      parent = create_feed(mime: "message/rfc822", title: "mail.eml",
                           locator_key: "#{box}/mail.eml")

      children.times do |n|
        child = create_feed(mime: "text/plain", title: "part-#{n}.txt",
                            locator_key: "#{box}/part-#{n}.txt")
        child.update!(parent: parent)
        Analysis.create!(feed: child, cause: "sync", status: "done",
                         steps: { "text" => { "result" => "part #{n}" } })
      end

      parent
    end
  end

  test "reading a family costs the same whether it has two children or twenty" do
    small = parent_with(children: 2)
    large = parent_with(children: 20)

    counts = [ small, large ].map do |parent|
      Tenant.switch(@tenant) do
        held = Feed.for_indexing.find(parent.id)
        count = 0
        counter = ->(*, payload) { count += 1 unless payload[:name] == "SCHEMA" }

        ActiveSupport::Notifications.subscribed(counter, "sql.active_record") do
          SearchIndex.document(held)
        end

        count
      end
    end

    assert_equal counts.first, counts.last,
                 "the query count grew with the number of children: #{counts.inspect}"
  end
end
