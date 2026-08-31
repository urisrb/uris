require "test_helper"

class ChildrenTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  setup do
    SearchIndex.reset!

    @tenant = Tenant.create!(subdomain: "kids-#{SecureRandom.hex(4)}", name: "Children")

    Tenant.switch(@tenant) do
      @mail = Resource::Database.create!(key: "mailbox")
      @mail.upload("march.eml", eml)
      @thing = Thing.create!(kind: "email", title: "March invoice")
      ThingReference.record!(thing: @thing, resource: @mail,
                             locator_key: "march.eml", locator: { "key" => "march.eml" })
    end
  end

  def eml(attachment: "invoice.txt", body: "the numbers are in the attachment")
    mail = Mail.new do
      from "ash@example.invalid"
      to "bea@example.invalid"
      subject "March invoice"

      text_part { body "Please see attached." }
    end

    mail.attachments[attachment] = { mime_type: "text/plain", content: body }
    mail.to_s
  end

  def analyze!
    Tenant.switch(@tenant) { Analyzer.for(@thing.reload).run }
  end

  def children
    Tenant.switch(@tenant) { @thing.reload.children.to_a }
  end

  test "an attachment is catalogued as a thing of its own, under the message" do
    analyze!

    held = children

    assert_equal 1, held.length
    assert_equal "invoice.txt", held.first.title
    assert_equal "text", held.first.kind
    assert_equal @thing.id, held.first.parent_id
    assert_equal "the numbers are in the attachment",
                 Tenant.switch(@tenant) { held.first.reference.download.read }
  end

  test "the message is not analyzed until its children are" do
    analyze!

    Tenant.switch(@tenant) do
      assert_nil @thing.reload.analyzed_at, "a message with unread attachments is not read yet"
      assert_not @thing.children_ready?
    end
  end

  test "reading the children lets the message through, and its body includes theirs" do
    analyze!

    children.each { |child| Tenant.switch(@tenant) { Analyzer.for(child).run } }

    analyze!

    Tenant.switch(@tenant) do
      held = @thing.reload

      assert held.analyzed_at.present?
      assert held.children_ready?
      assert_includes held.body_text, "the numbers are in the attachment"
      assert_includes held.body_text, "Please see attached"
    end
  end

  test "the last child to finish is what wakes the message" do
    analyze!

    child = children.first

    perform_enqueued_jobs(only: AnalyzeThingJob) do
      AnalyzeThingJob.perform_now(@tenant.id, child.id)
    end

    Tenant.switch(@tenant) { assert @thing.reload.analyzed_at.present? }
  end

  test "extraction is idempotent, so re-analysis finds its children rather than copying them" do
    analyze!
    analyze!
    analyze!

    assert_equal 1, children.length
  end

  test "re-analysis does not write the attachment's bytes again" do
    analyze!

    written = 0
    Resource::Database.class_eval do
      alias_method :upload_without_count, :upload
      define_method(:upload) { |name, body| written += 1; upload_without_count(name, body) }
    end

    begin
      analyze!
      analyze!
    ensure
      Resource::Database.class_eval do
        remove_method :upload
        alias_method :upload, :upload_without_count
        remove_method :upload_without_count
      end
    end

    assert_equal 0, written, "the bytes were already there; a re-read must not rewrite them"
  end

  test "an analyzer that declares no children extracts none" do
    Tenant.switch(@tenant) do
      @mail.upload("plain.txt", "nothing inside this")
      plain = Thing.create!(kind: "text", title: "plain.txt")
      ThingReference.record!(thing: plain, resource: @mail,
                             locator_key: "plain.txt", locator: { "key" => "plain.txt" })

      Analyzer.for(plain).run

      assert_empty plain.reload.children
      assert plain.analyzed_at.present?, "nothing to wait for means nothing waits"
    end
  end

  test "a message whose attachment is unreadable still reads itself" do
    Tenant.switch(@tenant) do
      @mail.upload("broken.eml", "this is not a message")
      broken = Thing.create!(kind: "email", title: "broken")
      ThingReference.record!(thing: broken, resource: @mail,
                             locator_key: "broken.eml", locator: { "key" => "broken.eml" })

      Analyzer.for(broken).run

      assert_empty broken.reload.children
      assert broken.analyzed_at.present?
    end
  end

  test "a child is searchable in its own right, and so is its parent by its contents" do
    analyze!
    children.each { |child| Tenant.switch(@tenant) { Analyzer.for(child).run } }
    analyze!

    SearchIndex.refresh!

    Tenant.switch(@tenant) do
      found = Thing.search("numbers").to_a

      assert_includes found.map(&:id), @thing.id
    end
  end

  test "nesting stops at a depth rather than following a message into itself" do
    Tenant.switch(@tenant) do
      deep = @thing
      Thing::DEPTH.times { deep = Thing.create!(kind: "email", title: "nested", parent: deep) }

      assert_equal Thing::DEPTH, deep.depth
    end
  end
end
