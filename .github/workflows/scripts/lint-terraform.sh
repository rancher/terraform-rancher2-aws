#!/bin/bash
set -e

terraform fmt -check -recursive
tflint --recursive
