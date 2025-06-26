variable "path" {
  type        = string
  description = <<-EOT
    The path to save the contents to.
  EOT
}
variable "recreate" {
  type        = string
  description = <<-EOT
    When this string changes, update the file snapshot.
  EOT
}
variable "contents" {
  type        = string
  description = <<-EOT
    The contents to persist, one of "contents" or "sourcefile" must be given.
  EOT
  default     = ""
}
variable "sourcefile" {
  type        = string
  description = <<-EOT
    A file to persist, one of "contents" or "sourcefile" must be given.
  EOT
  default     = ""
}
