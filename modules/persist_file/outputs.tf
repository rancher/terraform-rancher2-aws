output "contents" {
  value     = local_sensitive_file.file.content
  sensitive = true
}
