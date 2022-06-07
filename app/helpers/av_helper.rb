module AvHelper
  require 'streamio-ffmpeg'
  require 'json'
  require 'yaml'

  def ffmpegdata(path)
    mp4data = FFMPEG::Movie.new(path)
    returndata = {'metadata': mp4data.metadata, 'audiostreams': mp4data.audio_streams }
    return JSON.parse(returndata.to_json)
  end

  def waveformdata(input, output)
    ffmpegtranscode = FFMPEG::Movie.new(input)
    tmpfile = Tempfile.new(["waveformdata", ".wav"])
    ffmpegtranscode.transcode(tmpfile.path, %w(-vn -acodec pcm_s16le -ar 16000 -ac 1))
    Open3.capture3("audiowaveform -i #{input} -o #{output} --output-format json")
    tmpfile.unlink
  end
  
  def ffmpegcontentparse(content)
    return content.split(":")[-1].gsub!(/[^0-9\-.]/, '').strip.to_f
  end

  def captionpath(avmaterials)
    return avmaterials.exists('.vtt')['path']
  end


  def create_filepath(path)
    if !path.present?
      return nil
    end
    extname = File.extname(path)
    avtypes = ENV['avtypes'].split(",")
    upfiletypes = avtypes.map{|elem|elem.upcase}
    concatypes = upfiletypes.concat(avtypes).join(",")
    filepath = extname.present? ? path : File.join(path, "**", "*{#{concatypes}}")
    return filepath
  end

  def getSlug(path)
    return File.basename(path, '.*').gsub(" ", "_")
  end

  def secstovttformat(sec)
    seconds, point = sec.to_s.split(".")
    point = point.nil? ? "0" : point
    Time.at(seconds.to_i).utc.strftime("%H:%M:%S") + '.' + point[0..2].ljust(3, "0")
  end

  def aeneasforcedalignment(params)
    tmpfile = Tempfile.new('upload')
    tmpfile.write(params[:transcript].squish.gsub(/(?<=[.?!])(\s)/, "\n"))
    tmpfile.close
    avmaterial = Avmaterial.find_by slug: params[:slug]
    captionpath = captionpath(avmaterial)
    output = avmaterial.output
    audio = Dir.glob(File.join(output, "**", "*{mp4,mp3}"))
    aeneas = "python3 -m aeneas.tools.execute_task #{audio[0]} #{tmpfile.path} 'task_language=eng|os_task_file_format=vtt|is_text_type=plain' #{captionpath}"
    convertstdout, convertstderr, convertstatus = Open3.capture3(aeneas)
    puts convertstdout.inspect
    puts convertstderr.inspect
    tmpfile.unlink
    return convertstdout
  end

  def startendsilences(path, ffmpegdata)
    issilent = ffmpegdata['audiostreams'].length == 0 ? true : false
    startendsilences = [] 
    if !issilent
      volumedetect, volumedetecterr, volumedetectstatus = Open3.capture3("ffmpeg -i #{path.shellescape} -af 'volumedetect' -vn -sn -dn -f null /dev/null")
      maxvolume = ffmpegcontentparse(volumedetecterr.split("\n").grep(/max_volume/)[0])
      meanvolume = ffmpegcontentparse(volumedetecterr.split("\n").grep(/mean_volume/)[0])
      volume = meanvolume > -37 ? meanvolume - 1 : -37
      convertstdout, convertstderr, convertstatus = Open3.capture3("ffmpeg -i #{path.shellescape} -af silencedetect=n=#{volume}dB:d=0.5 -f null -")
      lines = convertstderr.split("\n")
      starttime = lines.grep(/silence_start/)
      endtimes = lines.grep(/silence_end/)
      starttime.each_with_index do |start, index|
        start = ffmpegcontentparse(start)
        endduration = endtimes[index].split("|")
        endtime = ffmpegcontentparse(endduration[0])
        duration = ffmpegcontentparse(endduration[1])
        startendsilences.push({'start': start, 'end': endtime, 'duration': duration})
      end   
      if startendsilences.length > 0
        avitemduration = ffmpegdata['metadata']['format']['duration'].to_f
        durations = startendsilences.map{|elem|elem[:duration]}.reduce(0, :+)
        issilent = (avitemduration - durations) < avitemduration/95
      end
      if !issilent
        issilent = (meanvolume < -40 && maxvolume < -30)
      end
    end
    return {'silencedata': startendsilences, 'issilent': issilent}
  end
  
  def getTranscript(avmaterial)
    transcriptpath = avmaterial.exists('.vtt')
    if transcriptpath['exists']
      parse = WebVTT.read(transcriptpath['path'])
      return parse.cues.map{|item|item.text}.join(" ")
    else
      return ''
    end
  end
end
