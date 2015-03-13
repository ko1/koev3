Object.send(:remove_const, :KoEV3) if defined? Object::KoEV3

module KoEV3
  class Sensor
    def initialize sensor_dir
      @sensor_dir = sensor_dir
    end

    def value n
      File.read(File.join(@sensor_dir, "value#{n}"))
    end

    def int_value n
      value(n).to_i
    end

    class GyroSensor < Sensor
      def angle
        int_value(0)
      end
    end

    class TouchSensor < Sensor
      def touch?
        int_value(0) == 1
      end
    end
  end

  class OutDevice
    def initialize device_dir
      @device_dir = device_dir
    end

    def out pairs
      pairs.each{|name, value|
        File.open(File.join(@device_dir, name.to_s), 'w'){|v_file|
          v_file.puts value
        }
      }
    end

    def input name
      File.open(File.join(@device_dir, name.to_s)){|f|
        f.read.chomp
      }
    end
  end

  class SideColorLED < OutDevice
    def initialize side, color
      super "/sys/class/leds/ev3:#{color}:#{side}"
      @max_brightness = input(:max_brightness).to_i
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
      out brightness: brightness
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

  class << TONE = OutDevice.new("/sys/devices/platform/snd-legoev3")
    def play freq, dur_ms
      out tone: "#{freq} #{dur_ms}"
    end

    def stop
      out tone: 0
    end
  end

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
  10.times{|i| KoEV3::TONE.play 200*i, 100; sleep 0.1}
end
