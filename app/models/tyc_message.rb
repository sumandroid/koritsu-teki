class TycMessage < ApplicationRecord
  enum message_type: [:text, :image, :video]

=begin
  has_attached_file :image, storage: :s3,
                    :path => 'tyc/:image_file_name',
                    :processors => [:transcoder],
                    :styles => {
                     :mp4video => { :geometry => '520x390', :format => 'mp4',
                                    :convert_options => { :output => { :vcodec => 'libx264', :b => '250k', :bt => '50k' } } } }

  validates_attachment :image, :content_type => { :content_type => ["video/x-flv", "video/mp4", "video/ogg", "video/webm", "video/x-ms-wmv", "video/x-msvideo", "video/quicktime", "video/3gpp"] }


  process_in_background :image
=end


  
  has_attached_file :image, storage: :s3,
                    :path => 'tyc/:styles/:image_file_name',
                    :styles => lambda {|a| a.instance.check_file_type},
                    :processors =>  lambda {|instance| (instance.message_type.eql? :image) ? '' : [:transcoder]}



  validates_attachment :image, :content_type => { :content_type => ["video/x-flv", "video/mp4", "video/ogg", "video/webm", "video/x-ms-wmv", "video/x-msvideo", "video/quicktime", "video/3gpp", 'image/jpeg', 'image/png'] }


  process_in_background :image

  Paperclip.interpolates :image_file_name do |attachment, style|
    attachment.instance.image_file_name
  end

  def image_file_name
    self.uid
  end

  def self.submit_thank_you_message(params)
    message_type = :video
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