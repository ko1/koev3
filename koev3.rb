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

    def out name, value
      File.open(File.join(@device_dir, name), 'w'){|v_file|
        v_file.puts value
      }
    end
  end

  class << TONE = OutDevice.new("/sys/devices/platform/snd-legoev3")
    def play freq, dur_ms
      out 'tone', "#{freq} #{dur_ms}"
    end

    def stop
      out 0
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
