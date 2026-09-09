class Api::V1::Accounts::UploadController < Api::V1::Accounts::BaseController
  def create
    result = if params[:attachment].present?
               create_from_file
             elsif params[:external_url].present?
               create_from_url
             else
               render_error(I18n.t('errors.upload.missing_input'), :unprocessable_entity)
             end

    render_success(result) if result.is_a?(ActiveStorage::Blob)
  end

  private

  def create_from_file
    attachment = params[:attachment]
    create_and_save_blob(attachment.tempfile, attachment.original_filename, attachment.content_type)
  end

  def create_from_url
    SafeFetch.fetch(params[:external_url].to_s) do |result|
      create_and_save_blob(result.tempfile, result.filename, result.content_type)
    end
  rescue SafeFetch::HttpError => e
    render_error(I18n.t('errors.upload.fetch_failed_with_message', message: e.message), :unprocessable_entity)
  rescue SafeFetch::FetchError
    render_error(I18n.t('errors.upload.fetch_failed'), :unprocessable_entity)
  rescue SafeFetch::FileTooLargeError
    render_error(I18n.t('errors.upload.file_too_large'), :unprocessable_entity)
  rescue SafeFetch::UnsupportedContentTypeError
    render_error(I18n.t('errors.upload.unsupported_content_type'), :unprocessable_entity)
  rescue SafeFetch::Error
    render_error(I18n.t('errors.upload.invalid_url'), :unprocessable_entity)
  rescue StandardError
    render_error(I18n.t('errors.upload.unexpected'), :internal_server_error)
  end

  def create_and_save_blob(io, filename, content_type)
    ActiveStorage::Blob.create_and_upload!(
      io: io,
      filename: filename,
      content_type: content_type
    )
  end

  def render_success(file_blob)
    render json: { file_url: public_url_for(file_blob), blob_id: file_blob.signed_id }
  end

  # Everything uploaded here ends up embedded in content the public already reads - help centre
  # articles, portal logos, flow images in the live-chat widget - and the Rails URL this used to
  # return was itself unauthenticated and permanent. Serving from the storage CDN keeps that
  # contract and takes Rails out of the path on every view.
  def public_url_for(blob)
    cdn_url = ENV.fetch('STORAGE_CDN_URL', '')
    return url_for(blob) if cdn_url.blank?

    "#{cdn_url.chomp('/')}/#{blob.key}"
  end

  def render_error(message, status)
    render json: { error: message }, status: status
  end
end
