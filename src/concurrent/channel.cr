require "fiber"

abstract class Channel(T)
  def initialize
    @senders = [] of Fiber
    @receivers = [] of Fiber
  end

  def self.new
    UnbufferedChannel(T).new
  end

  def self.new(capacity)
    BufferedChannel(T).new(capacity)
  end

  def self.select(*channels)
    loop do
      ready_channel = channels.find &.ready?
      return ready_channel if ready_channel

      channels.each &.wait
      Scheduler.reschedule
      channels.each &.unwait
    end
  end

  protected def wait
    @receivers << Fiber.current
  end

  protected def unwait
    @receivers.delete Fiber.current
  end
end

class BufferedChannel(T) < Channel(T)
  def initialize(@capacity = 32)
    @queue = Array(T).new(@capacity)
    super()
  end

  def send(value : T)
    while full?
      @senders << Fiber.current
      Scheduler.reschedule
    end

    @queue << value
    Scheduler.enqueue @receivers
    @receivers.clear
  end

  def receive
    while empty?
      @receivers << Fiber.current
      Scheduler.reschedule
    end

    @queue.shift.tap do
      Scheduler.enqueue @senders
      @senders.clear
    end
  end

  def full?
    @queue.length >= @capacity
  end

  def empty?
    @queue.empty?
  end

  def ready?
    !empty?
  end
end

class UnbufferedChannel(T) < Channel(T)
  def initialize
    @has_value = false
    @value :: T
    super
  end

  def send(value : T)
    while @has_value
      @senders << Fiber.current
      Scheduler.reschedule
    end

    @value = value
    @has_value = true
    @sender = Fiber.current

    if receiver = @receivers.pop?
      receiver.resume
    else
      Scheduler.reschedule
    end
  end

  def receive
    until @has_value
      @receivers << Fiber.current
      if sender = @senders.pop?
        sender.resume
      else
        Scheduler.reschedule
      end
    end

    @value.tap do
      @has_value = false
      Scheduler.enqueue @sender.not_nil!
    end
  end

  def ready?
    @has_value
  end
end
