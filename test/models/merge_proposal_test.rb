require "test_helper"

class MergeProposalTest < ActiveSupport::TestCase
  setup do
    SearchIndex.reset!

    @tenant = Tenant.create!(subdomain: "dedupe-#{SecureRandom.hex(4)}", name: "Dedupe")

    Tenant.switch(@tenant) do
      @drive = Resource::S3.create!(key: "drive", details: { "endpoint" => "http://127.0.0.1:1" })
      @backup = Resource::S3.create!(key: "backup", details: { "endpoint" => "http://127.0.0.1:1" })
    end
  end

  def thing_on(resource, key, kind: "pdf", version: nil, title: nil)
    Tenant.switch(@tenant) do
      thing = Thing.create!(kind: kind, title: title || File.basename(key))
      ThingReference.create!(thing: thing, resource: resource, locator_key: key,
                             locator: {}, version: version)
      thing
    end
  end

  def propose!
    ProposeMergesJob.perform_now(@tenant.id)

    Tenant.switch(@tenant) { MergeProposal.open.order(:blocking_key).to_a }
  end

  test "the same name in two places is proposed, and a unique name is not" do
    a = thing_on(@drive, "2024/invoices/march.pdf")
    b = thing_on(@backup, "archive/march.pdf")
    thing_on(@drive, "2024/invoices/april.pdf")

    proposals = propose!

    assert_equal 1, proposals.length
    assert_equal "same-name", proposals.first.reason
    assert_equal [ a.id, b.id ].sort, proposals.first.thing_ids
  end

  test "the same name of a different kind is not the same thing" do
    thing_on(@drive, "notes/report.pdf", kind: "pdf")
    thing_on(@backup, "notes/report.pdf", kind: "text")

    assert_empty propose!
  end

  test "two references reporting the same version on the same type are proposed" do
    a = thing_on(@drive, "one.pdf", version: "etag-abc")
    b = thing_on(@backup, "quite-another-name.pdf", version: "etag-abc")

    proposals = propose!.select { |held| held.reason == "same-bytes" }

    assert_equal 1, proposals.length
    assert_equal [ a.id, b.id ].sort, proposals.first.thing_ids
  end

  test "the same version string from two different types is not a match" do
    other = Tenant.switch(@tenant) do
      Resource::Filesystem.create!(key: "disk", details: { "root" => "/tmp" })
    end

    thing_on(@drive, "one.pdf", version: "collides")
    thing_on(other, "two.pdf", version: "collides")

    assert_empty propose!.select { |held| held.reason == "same-bytes" }
  end

  test "a thing is never proposed against itself" do
    thing = thing_on(@drive, "one.pdf")

    Tenant.switch(@tenant) do
      ThingReference.create!(thing: thing, resource: @backup, locator_key: "one.pdf", locator: {})
    end

    assert_empty propose!
  end

  test "running twice leaves one proposal, not two" do
    thing_on(@drive, "march.pdf")
    thing_on(@backup, "march.pdf")

    propose!
    proposals = propose!

    assert_equal 1, proposals.length
  end

  test "accepting merges the references onto the oldest and settles the proposal" do
    a = thing_on(@drive, "march.pdf")
    b = thing_on(@backup, "march.pdf")

    proposal = propose!.first

    Tenant.switch(@tenant) do
      kept = proposal.accept!

      assert_equal a.id, kept.id
      assert_equal 2, kept.references.count
      assert_nil Thing.find_by(id: b.id)
      assert_equal "accepted", proposal.reload.status
      assert proposal.settled_at.present?
    end
  end

  test "rejecting settles it and merges nothing" do
    a = thing_on(@drive, "march.pdf")
    b = thing_on(@backup, "march.pdf")

    proposal = propose!.first

    Tenant.switch(@tenant) do
      proposal.reject!

      assert_equal "rejected", proposal.reload.status
      assert_equal 1, Thing.find(a.id).references.count
      assert Thing.find_by(id: b.id).present?
    end
  end

  test "a proposal whose things have moved on is refused rather than acted on" do
    thing_on(@drive, "march.pdf")
    b = thing_on(@backup, "march.pdf")

    proposal = propose!.first

    Tenant.switch(@tenant) do
      Thing.find(b.id).destroy!

      assert_not proposal.current?
      assert_raises(MergeProposal::Stale) { proposal.accept! }
    end
  end

  test "one tenant's proposals are invisible to another" do
    thing_on(@drive, "march.pdf")
    thing_on(@backup, "march.pdf")
    propose!

    elsewhere = Tenant.create!(subdomain: "dedupe-#{SecureRandom.hex(4)}", name: "Elsewhere")

    Tenant.switch(elsewhere) { assert_empty MergeProposal.unscoped.to_a }
    Tenant.switch(@tenant) { assert_equal 1, MergeProposal.unscoped.count }
  end

  test "a dry run reports what it would propose and writes nothing" do
    thing_on(@drive, "march.pdf")
    thing_on(@backup, "march.pdf")

    Tenant.switch(@tenant) { Gate.create!(key: "dedupe", enabled: true, live: false) }

    ProposeMergesJob.perform_now(@tenant.id)

    Tenant.switch(@tenant) { assert_empty MergeProposal.all }
  end
end
