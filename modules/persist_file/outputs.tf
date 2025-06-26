# output "encoded_contents" {
#   value = base64encode(filesystem_file_writer.file.contents)
# }

output "contents" {
  value = local_file.file.content #filesystem_file_writer.file.contents
}
