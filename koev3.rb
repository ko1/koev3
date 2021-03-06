Object.send(:remove_const, :KoEV3) if defined? Object::KoEV3

module KoEV3
  def self.reload
    load __FILE__
  end

  class Device
    def initialize class_dir
      @class_dir = class_dir
    end

    def read name
      File.open(File.join(@class_dir, name.to_s)){|f|
        f.read.chomp
      }
    end

    def write name, value
      File.open(File.join(@class_dir, name), 'w'){|f|
        f.write value.to_s
      }
    end

    def self.device_attr_reader name, type = nil
      case type
      when nil
        trans = ''
      when :int
        trans = '.to_i'
      when :float
        trans = '.to_f'
      when :str_seq
        trans = '.split(/\s/)'
      else
        raise "Unsupported type: #{type}"
      end

      self.class_eval %Q{
        def #{name}
          read("#{name}")#{trans}
        end
      }
    end

    def self.device_attr_writer name
      self.class_eval %Q{
        def #{name}=(value)
          write("#{name}", value)
        end
      }
    end

    def self.device_attr name, type = nil
      device_attr_reader name, type
      device_attr_writer name
    end
  end

  class Sensor < Device
    10.times{|i|
      device_attr_reader "value#{i}", :int
    }
    device_attr_reader "modes"
    device_attr "mode"

    def set_mdoe m
      raise "unknown mode: #{m}" unless @modes.include?(m)
      self.mode = m
    end

    def initialize class_dir
      super
      @modes = self.modes.split(/\s/)
    end

    class GyroSensor < Sensor
      def angle
        value0
      end

      def rotation_speed
        value0
      end
    end

    class TouchSensor < Sensor
      def touch?
        value0 == 1
      end
    end
  end

  class TachoMotor < Device
    device_attr_reader :encoder_modes, :str_seq
    device_attr_reader :polarity_modes, :str_seq
    device_attr_reader :position_modes, :str_seq
    device_attr_reader :regulation_modes, :str_seq
    device_attr_reader :run_modes, :str_seq
    device_attr_reader :stop_modes, :str_seq
    device_attr_reader :port_name
    device_attr_reader :state
    device_attr_reader :type
    device_attr_reader :duty_cycle, :int

    device_attr :duty_cycle_sp, :int
    device_attr :encoder_mode
    device_attr :estop, :int
    device_attr :polarity_mode
    device_attr :position, :int
    device_attr :position_mode
    device_attr :position_sp, :int
    device_attr :pulses_per_second, :int
    device_attr :pulses_per_second_sp, :int
    device_attr :ramp_down_sp, :int
    device_attr :ramp_up_sp, :int
    device_attr :regulation_mode
    device_attr :run, :int
    device_attr :run_mode
    device_attr :speed_regulation_D, :int
    device_attr :speed_regulation_I, :int
    device_attr :speed_regulation_K, :int
    device_attr :speed_regulation_P, :int
    device_attr :stop_mode
    device_attr :time_sp, :int

    def initialize class_path
      super
    end

    def run
      self.run = 1
    end

    def stop
      self.run = 0
    end

    def estop
      self.estop = 1
    end

    def cancel_estop
      n = self.estop
      self.estop = n if n != 0
    end

    def speed sp
      self.duty_cycle_sp = sp
    end
  end

  TACHO_MOTORS = []

  Dir.glob("/sys/class/tacho-motor/motor*"){|dir|
    TACHO_MOTORS << TachoMotor.new(dir)
  }

  class SideColorLED < Device
    device_attr_reader :max_brightness, :int
    device_attr :brightness, :int

    def initialize side, color
      super "/sys/class/leds/ev3:#{color}:#{side}"
      @max_brightness = self.max_brightness
    end

    def on brightness = 255
      set_brightness brightness
    end

    def off brightness = 0
      set_brightness brightness
    end

    def set_brightness brightness
      raise if brightness < 0
      raise if brightness > @max_brightness
      self.brightness = brightness
    end
  end

  LEFT_GREEN_LED  = SideColorLED.new(:left, :green)
  LEFT_RED_LED    = SideColorLED.new(:left, :red)
  RIGHT_GREEN_LED = SideColorLED.new(:right, :green)
  RIGHT_RED_LED   = SideColorLED.new(:right, :red)

  class SideLED
    def initialize green, red
      @green = green
      @red = red
      @LEDS = [green, red]
    end

    COLORS = [:green, :red, :yellow, :orange, :amber, :black]

    def on color
      case color
      when :green
        @green.on
        @red.off
      when :red
        @green.off
        @red.on
      when :yellow
        @green.on
        @red.on 25
      when :orange
        @green.on 255
        @red.on 120
      when :amber
        @green.on
        @red.on
      when :black
        @green.off
        @red.off
      else
        raise "unsupported color: #{color}"
      end
    end

    def off
      @LEDS.each{|l| l.off }
    end
  end

  LEFT_LED  = SideLED.new(LEFT_GREEN_LED, LEFT_RED_LED)
  RIGHT_LED = SideLED.new(RIGHT_GREEN_LED, RIGHT_RED_LED)

  def (BOTH_LED = Object.new).off
    LEFT_LED.off
    RIGHT_LED.off
  end

  class Tone < Device
    device_attr :tone, :int

    def play freq, dur_ms
      self.tone = "#{freq} #{dur_ms}"
    end

    def stop
      self.tone = 0
    end
  end

  TONE = Tone.new("/sys/devices/platform/snd-legoev3")

  # initialize sensors
  Dir.glob('/sys/class/lego-sensor/sensor*/driver_name'){|file|
    driver_name = File.read(file).chomp
    sensor_dir = File.dirname(file)

    case driver_name
    when "lego-ev3-uart-32"
      GYRO_SENSOR = Sensor::GyroSensor.new(sensor_dir)
    when "lego-ev3-touch"
      TOUCH_SENSOR = Sensor::TouchSensor.new(sensor_dir)
    end
  }
end

if $0 == __FILE__
  begin
    colors = KoEV3::SideLED::COLORS.cycle
    10.times{|i|
      KoEV3::TONE.play 200*i, 200
      KoEV3::LEFT_LED.on colors.next
      KoEV3::RIGHT_LED.on colors.next
      sleep 0.1
    }
  ensure
    KoEV3::LEFT_LED.off
    KoEV3::RIGHT_LED.off
  end
end
