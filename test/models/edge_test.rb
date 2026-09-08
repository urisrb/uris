require "test_helper"

class EdgeTest < ActiveSupport::TestCase
  setup do
    @tenant = Tenant.create!(subdomain: "edge-#{SecureRandom.hex(4)}", name: "Edges")

    Tenant.switch(@tenant) do
      @one = Feed.create!(type: Feed::FILE, key: "one", title: "one")
      @two = Feed.create!(type: Feed::FILE, key: "two", title: "two")
    end
  end

  def low_and_high
    [ @one, @two ].sort_by(&:id)
  end

  test "a pair is stored with the lower id first, whichever way it is made" do
    low, high = low_and_high

    Tenant.switch(@tenant) do
      edge = high.connect!(low)

      assert_equal low.id, edge.a_id
      assert_equal high.id, edge.b_id
    end
  end

  test "the database refuses a reversed duplicate, not only the model" do
    low, high = low_and_high

    Tenant.switch(@tenant) do
      low.connect!(high)

      assert_raises ActiveRecord::StatementInvalid do
        Edge.transaction(requires_new: true) do
          Edge.insert_all!([ { tenant_id: @tenant.id, a_id: high.id, b_id: low.id,
                               created_at: Time.current, updated_at: Time.current } ])
        end
      end

      assert_equal 1, Edge.count, "the reversed row never landed"
    end
  end

  test "the check constraint refuses a pair that is not canonical" do
    low, high = low_and_high

    Tenant.switch(@tenant) do
      reversed = Edge.new(a_id: high.id, b_id: low.id)

      assert_not reversed.valid?
      assert_match(/is not the lower half/, reversed.errors[:a_id].first)
    end
  end

  test "a feed cannot connect to itself" do
    Tenant.switch(@tenant) do
      assert_raises(ArgumentError) { @one.connect!(@one) }

      loop_back = Edge.new(a_id: @one.id, b_id: @one.id)

      assert_not loop_back.valid?
      assert_match(/cannot connect a feed to itself/, loop_back.errors[:a_id].first)
    end
  end

  test "connecting twice is one edge, and severing it leaves none" do
    Tenant.switch(@tenant) do
      @one.connect!(@two)
      @one.connect!(@two)
      @two.connect!(@one)

      assert_equal 1, Edge.count

      @two.disconnect!(@one)

      assert_equal 0, Edge.count
      assert_empty @one.connected
    end
  end

  test "the other end of an edge is whichever half you did not ask about" do
    Tenant.switch(@tenant) do
      edge = @one.connect!(@two)

      assert_equal @two, edge.other_than(@one)
      assert_equal @one, edge.other_than(@two)
      assert_equal @two, edge.other_than(@one.id)
    end
  end
end
