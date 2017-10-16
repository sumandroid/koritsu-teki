class TycMessage < ApplicationRecord
  enum message_type: [:text, :image, :video]

  has_attached_file :image, storage: :s3,
                    :path => 'tyc/:styles/:image_file_name',
                    :styles => lambda {|a| a.instance.check_file_type}, #check file type and return the styles accordingly. Lambda is passed the attachment
                    :processors =>  lambda {|instance| (instance.message_type.eql? :image) ? '' : [:transcoder]} #check the file type and return the processor accordingly. Lambda is passed the instance of the attachment.



  #validates the input type, change accordingly as to which file types you want to handle.
  validates_attachment :image, :content_type => { :content_type => ["video/x-flv", "video/mp4", "video/ogg", "video/webm", "video/x-ms-wmv", "video/x-msvideo", "video/quicktime", "video/3gpp", 'image/jpeg', 'image/png'] }


  #process the attachment in background using the delayed_paperclip gem
  process_in_background :image

  #interpolates the file name accordingly
  Paperclip.interpolates :image_file_name do |attachment, style|
    attachment.instance.image_file_name
  end

  def image_file_name
    self.uid
  end

  def self.submit_thank_you_message(params)
    if params[:image_file].content_type =~ %r(video)
      message_type = :video
    elsif params[:image_file].content_type =~ %r(image)
      message_type = :image
    else
      message_type = :text
    end
    message_body = "#{params[:message_1]}||#{params[:message_2]}"
    thank_you_message = self.new({
                                    :uid => CommonUtils.generate_random_string(6),
                                    :sender_name => params[:sender_name].downcase,
                                    :sender_phone => params[:sender_phone],
                                    :sender_email => params[:sender_email],
                                    :sender_institute => params[:sender_institute].downcase,
                                    :receiver_name => params[:receiver_name].downcase,
                                    :receiver_email => params[:receiver_email],
                                    :receiver_phone => params[:receiver_phone],
                                    :receiver_institute => params[:receiver_institute].downcase,
                                    :message_type => message_type,
                                    :message_body => message_body,
                                    :media_link => params[:media_link]
                                 })
    if params[:image_file].present?
      thank_you_message.image = params[:image_file]
      thank_you_message.image_file_name = thank_you_message.uid + File.extname(params[:image_file].original_filename)
    end
    thank_you_message.save
    return thank_you_message
  end

  def check_file_type
    if is_image?
      {}
    elsif is_video?
      {
       :original => { :geometry => '520x390', :format => 'mp4',
                      :convert_options => { :output => { :vcodec => 'libx264', :b => '250k', :bt => '50k' } } },
       :thumb => { :geometry => "200x200#", :format => 'jpg', :time => 10 }
      }
    end
  end

  private

  def is_video?
    self.message_type =~ %r(video)
  end

  def is_image?
    self.message_type =~ %r(image)
  end

end