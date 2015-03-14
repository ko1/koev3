Object.send(:remove_const, :KoEV3) if defined? Object::KoEV3

module KoEV3
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
      File.open(File.join(@class_dir, name.to_s), 'w'){|f|
        f.write value
      }
    end

    def self.device_attr_reader name
      self.class_eval %Q{
        def #{name}
          read("#{name}")
        end

        def int_#{name}
          read("#{name}").to_i
        end
      }
    end

    def self.device_attr_writer name
      self.class_eval %Q{
        def #{name}=(value)
          read("#{name}")
        end
      }
    end

    def self.device_attr name
      device_attr_reader name
      device_attr_writer name
    end
  end

  class Sensor < Device
    10.times{|i|
      device_attr_reader "value#{i}"
    }

    class GyroSensor < Sensor
      def angle
        int_value0
      end
    end

    class TouchSensor < Sensor
      def touch?
        int_value0 == 1
      end
    end
  end

  class SideColorLED < Device
    device_attr_reader :max_brightness
    device_attr :brightness

    def initialize side, color
      super "/sys/class/leds/ev3:#{color}:#{side}"
      @max_brightness = int_max_brightness
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

  class Tone < Device
    device_attr :tone

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
  colors = KoEV3::SideLED::COLORS.cycle
  10.times{|i|
    KoEV3::TONE.play 200*i, 100
    KoEV3::LEFT_LED.on colors[i]
    KoEV3::WRITE_LED.on colors[i+1]
    sleep 0.1
  }
end
