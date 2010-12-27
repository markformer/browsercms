require_relative '../../test_helper'

class AttachmentTest < ActiveSupport::TestCase

  def setup
    @file = file_upload_object({:original_filename=>"sample_upload.txt", :content_type=>"text/plain"})

  end

  def test_creating_an_attachment_with_no_file
    attachment = Attachment.new
    assert_not_valid attachment
    assert_has_error_on attachment, :temp_file, "You must upload a file"
  end

  def test_creating_an_attachment_with_a_StringIO_file
    file = @file
    attachment = Attachment.new(:temp_file => file, :file_path => "/sample_upload.txt", :section => root_section)
    attachment.save!
    assert_equal "sample_upload.txt", attachment.file_name
    assert_equal "text/plain", attachment.file_type
    assert_equal "txt", attachment.file_extension
    assert_file_exists attachment.full_file_location
    assert_equal "This is a file.", open(attachment.full_file_location) { |f| f.read }
  end

  def test_creating_an_attachment_with_a_Tempfile_file
    file = @file
    attachment = Attachment.new(:temp_file => file, :file_path => "/foo.txt", :section => root_section)
    attachment.save!

    assert_equal "foo.txt", attachment.file_name
    assert_file_exists attachment.full_file_location
    assert_equal "This is a file.", open(attachment.full_file_location) { |f| f.read }

    # If you change the attributes of the attachment, but don't change the file
    # the file_location should not change
    original_file_location = attachment.file_location
    attachment = Attachment.find(attachment.id)
    attachment.update_attributes(:file_path => "bar.txt")
    assert_equal 2, attachment.draft.version
    assert_equal "/bar.txt", attachment.file_path
    assert_equal "bar.txt", attachment.file_name
    assert_equal original_file_location, attachment.file_location

    # If you change the file of the attachment, the file_location should change
    attachment = Attachment.find(attachment.id)

    file = file_upload_object(:original_filename=>"second_upload.txt", :content_type=>"text/plain")
    attachment.update_attributes(:temp_file => file)
    # log_table_with Attachment, :id, :name, :version, :file_path
    # log_table_with Attachment::Version, :id, :name, :version, :file_path, :attachment_id
    assert_equal 3, attachment.draft.version
    assert_equal "/foo.txt", attachment.as_of_draft_version.file_path, "Updating the file itself should also update the name of the file. (Note:This might just be an invalid test)"
    assert_equal "foo.txt", attachment.as_of_draft_version.file_name
    assert_not_equal original_file_location, attachment.as_of_draft_version.file_location
    assert_equal "This is a second file.", open(attachment.as_of_draft_version.full_file_location) { |f| f.read }
  end

  def test_find_live_by_file_path
    file = @file
    attachment = Attachment.new(:temp_file => file, :file_path => "/foo.txt", :section => root_section)
    attachment.save!
    assert !attachment.published?, "Attachment should not be published"
    assert_nil Attachment.find_live_by_file_path("/foo.txt")

    attachment.publish
    assert attachment.reload.published?, "Attachment should be published"
    assert_equal attachment, Attachment.find_live_by_file_path("/foo.txt")

    attachment.update_attributes(:file_type => "text/html")
    assert !attachment.live?, "Attachment should not be live"
    assert_equal attachment.as_of_version(2), Attachment.find_live_by_file_path("/foo.txt")
  end
end

class Attachment::SectionTest < ActiveSupport::TestCase

  def setup
    @file = file_upload_object({:original_filename=>"sample_upload.txt", :content_type=>"text/plain"})
    @attachment = Attachment.create!(:temp_file => @file, :file_path => "/foo.txt", :section => root_section)
    @attachment = Attachment.find(@attachment.id) # Force reload
  end

  test "Setting the section on an attachment persists that section" do
    assert_equal root_section, @attachment.section, "Should be associated with the root section"
  end

  test "Replacing an existing section should update it" do
    new_section = Factory(:section)
    @attachment.section = new_section
    @attachment.save!
    @attachment = Attachment.find(@attachment.id) # Force reload
    assert_equal new_section, @attachment.section
  end
end