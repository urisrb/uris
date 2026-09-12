require "test_helper"

class ScheduleTest < ActiveSupport::TestCase
  setup do
    @tenant = Tenant.create!(subdomain: "schedule-#{SecureRandom.hex(4)}", name: "Schedule")
  end

  def made(**attrs)
    feed = Feed.create!(type: Feed::ADDRESS, key: "/watch-#{SecureRandom.hex(4)}")

    feed.create_schedule!({ prompt: "anything new?" }.merge(attrs))
  end

  test "a schedule made with an interval is due an interval from now, however it was made" do
    Tenant.switch(@tenant) do
      schedule = made(interval: 1.hour.to_i)

      assert_in_delta 1.hour.from_now, schedule.next_run_at, 5
    end
  end

  test "a schedule with no interval is never due" do
    Tenant.switch(@tenant) { assert_nil made.next_run_at }
  end

  test "changing the interval moves the next run, and changing the prompt does not" do
    Tenant.switch(@tenant) do
      schedule = made(interval: 1.hour.to_i, next_run_at: 10.minutes.from_now)
      schedule.update!(prompt: "anything else?")

      assert_in_delta 10.minutes.from_now, schedule.next_run_at, 5

      schedule.update!(interval: 1.day.to_i)

      assert_in_delta 1.day.from_now, schedule.next_run_at, 5
    end
  end

  test "pausing clears the next run and resuming sets it again" do
    Tenant.switch(@tenant) do
      schedule = made(interval: 1.hour.to_i)
      schedule.pause!

      assert_nil schedule.next_run_at
      assert_not Schedule.due.exists?(schedule.id)

      schedule.resume!

      assert_in_delta 1.hour.from_now, schedule.next_run_at, 5
    end
  end

  test "dropping the interval clears the next run" do
    Tenant.switch(@tenant) do
      schedule = made(interval: 1.hour.to_i)
      schedule.update!(interval: nil)

      assert_nil schedule.next_run_at
    end
  end
end
