require 'rubygems'
require 'google_drive'

class ReportCreator
  def find_most_csv_values(path = './remote*_fps.csv')
    counts = Hash.new

    Dir.glob(path) do |filename|
      #count = File.read(filename).strip.split(',').length
      count = `wc -l #{filename}`.split[0]
      counts[filename] = Integer(count)
    end

    counts.sort_by {|key, val| val}.last[1]
  end

  def pad_csv_files(count, path = './remote*_fps.csv')
    Dir.glob(path) do |filename|
      curr_count = Integer(`wc -l #{filename}`.split[0])
      diff_count = count - curr_count

      if diff_count > 0 
        File.open('temp.csv', 'w') do |file|
          while diff_count > 0
            file.puts "0\n"
            diff_count = diff_count - 1
          end 

          file.write(File.open(filename, 'r').read())
          `mv #{filename} #{filename}.bak`
          `mv temp.csv #{filename}`
        end
      end
    end
  end

  def add_csv_files_to_spreadsheet(spreadsheet, path = './remote*_fps.csv')
    highest_count = find_most_csv_values

    Dir.glob(path) do |filename|
      print "Adding CSV file: #{filename}"

      diff_count = highest_count - Integer(`wc -l #{filename}`.split[0])
      worksheet = spreadsheet.add_worksheet(filename)
      ws_index = 1

      if diff_count > 0 
        while ws_index <= diff_count
          worksheet[ws_index, 1] = 0
          ws_index = ws_index + 1
        end 
      end

      File.open(filename, 'r') do |f|
        while line = f.gets
          worksheet[ws_index, 1] = Integer(line.scan(/\d+/).first)
          ws_index = ws_index + 1
        end
      end

      worksheet.save()

      puts " - Done."
    end
  end

  def create_report(username, password, report_name = 'profiler_report')
    session = GoogleDrive.login(username, password)
    template = session.spreadsheet_by_url('https://docs.google.com/spreadsheet/ccc?key=0ArmaMDqoHvnNdE8zTE9pMkw1VUlZTkVYYlhNeXc4WGc')
    spreadsheet = template.duplicate(report_name)
    add_csv_files_to_spreadsheet(spreadsheet)
  end
end

