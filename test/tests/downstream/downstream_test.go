package one

import (
  "os"
  "path/filepath"
  "testing"

  aws "github.com/gruntwork-io/terratest/modules/aws"
  g "github.com/gruntwork-io/terratest/modules/git"
  "github.com/gruntwork-io/terratest/modules/ssh"
  "github.com/gruntwork-io/terratest/modules/terraform"
  util "github.com/rancher/terraform-rancher2-aws/test/tests"
)

func TestDownstreamBasic(t *testing.T) {
  t.Parallel()
  id := util.GetId()
  region := util.GetRegion()
  accessKey := util.GetAwsAccessKey()
  secretKey := util.GetAwsSecretKey()
  directory := "deploy_rke2"
  owner := "terraform-ci@suse.com"
  util.SetAcmeServer()

  repoRoot, err := filepath.Abs(g.GetRepoRoot(t))
  if err != nil {
    t.Fatalf("Error getting git root directory: %v", err)
  }

  exampleDir := repoRoot + "/examples/" + directory
  testDir := repoRoot + "/test/tests/data/" + id

  err = util.CreateTestDirectories(t, id)
  if err != nil {
    os.RemoveAll(testDir)
    t.Fatalf("Error creating test data directories: %s", err)
  }
  keyPair, err := util.CreateKeypair(t, region, owner, id)
  if err != nil {
    os.RemoveAll(testDir)
    t.Fatalf("Error creating test key pair: %s", err)
  }
  sshAgent := ssh.SshAgentWithKeyPair(t, keyPair.KeyPair)
  t.Logf("Key %s created and added to agent", keyPair.Name)

  // use oldest RKE2, remember it releases much more than Rancher
  _, _, rke2Version, err := util.GetRke2Releases()
  if err != nil {
    os.RemoveAll(testDir)
    aws.DeleteEC2KeyPair(t, keyPair)
    sshAgent.Stop()
    t.Fatalf("Error getting Rke2 release version: %s", err)
  }
  
  // use latest Rancher, due to community patch issue
  rancherVersion, _, _, err := util.GetRancherReleases()
  if err != nil {
    os.RemoveAll(testDir)
    aws.DeleteEC2KeyPair(t, keyPair)
    sshAgent.Stop()
    t.Fatalf("Error getting Rancher release version: %s", err)
  }

  terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
    TerraformDir: exampleDir,
    // Variables to pass to our Terraform code using -var options
    Vars: map[string]interface{}{
      "identifier":            id,
      "owner":                 owner,
      "key_name":              keyPair.Name,
      "key":                   keyPair.KeyPair.PublicKey,
      "zone":                  os.Getenv("ZONE"),
      "rke2_version":          rke2Version,
      "rancher_version":       rancherVersion,
      "file_path":             testDir,
      "aws_access_key_id":     accessKey,
      "aws_secret_access_key": secretKey,
      "aws_region":            region,
    },
    // Environment variables to set when running Terraform
    EnvVars: map[string]string{
      "AWS_DEFAULT_REGION":  region,
      "AWS_REGION":          region,
      "TF_DATA_DIR":         testDir,
      "TF_IN_AUTOMATION":    "1",
      "TF_CLI_ARGS_plan":    "-no-color -state=" + testDir + "/tfstate",
      "TF_CLI_ARGS_apply":   "-no-color -state=" + testDir + "/tfstate",
      "TF_CLI_ARGS_destroy": "-no-color -state=" + testDir + "/tfstate",
      "TF_CLI_ARGS_output":  "-no-color -state=" + testDir + "/tfstate",
    },
    RetryableTerraformErrors: util.GetRetryableTerraformErrors(),
    NoColor:                  true,
    SshAgent:                 sshAgent,
    Upgrade:                  true,
  })

  _, err = terraform.InitAndApplyE(t, terraformOptions)
  if err != nil {
    util.Teardown(t, testDir, terraformOptions, keyPair)
    os.Remove(exampleDir + ".terraform.lock.hcl")
    sshAgent.Stop()
    t.Fatalf("Error creating cluster: %s", err)
  }
  t.Log("Test passed, tearing down...")
  util.Teardown(t, testDir, terraformOptions, keyPair)
  os.Remove(exampleDir + ".terraform.lock.hcl")
  sshAgent.Stop()
}




func TestDownstreamProd(t *testing.T) {
  t.Parallel()
  id := util.GetId()
  region := util.GetRegion()
  accessKey := util.GetAwsAccessKey()
  secretKey := util.GetAwsSecretKey()
  directory := "deploy_rke2_multiple_pools"
  owner := "terraform-ci@suse.com"
  util.SetAcmeServer()

  repoRoot, err := filepath.Abs(g.GetRepoRoot(t))
  if err != nil {
    t.Fatalf("Error getting git root directory: %v", err)
  }

  exampleDir := repoRoot + "/examples/" + directory
  testDir := repoRoot + "/test/tests/data/" + id

  err = util.CreateTestDirectories(t, id)
  if err != nil {
    os.RemoveAll(testDir)
    t.Fatalf("Error creating test data directories: %s", err)
  }
  keyPair, err := util.CreateKeypair(t, region, owner, id)
  if err != nil {
    os.RemoveAll(testDir)
    t.Fatalf("Error creating test key pair: %s", err)
  }
  sshAgent := ssh.SshAgentWithKeyPair(t, keyPair.KeyPair)
  t.Logf("Key %s created and added to agent", keyPair.Name)

  // use oldest RKE2, remember it releases much more than Rancher
  _, _, rke2Version, err := util.GetRke2Releases()
  if err != nil {
    os.RemoveAll(testDir)
    aws.DeleteEC2KeyPair(t, keyPair)
    sshAgent.Stop()
    t.Fatalf("Error getting Rke2 release version: %s", err)
  }
  
  // use latest Rancher, due to community patch issue
  rancherVersion, _, _, err := util.GetRancherReleases()
  if err != nil {
    os.RemoveAll(testDir)
    aws.DeleteEC2KeyPair(t, keyPair)
    sshAgent.Stop()
    t.Fatalf("Error getting Rancher release version: %s", err)
  }

  terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
    TerraformDir: exampleDir,
    // Variables to pass to our Terraform code using -var options
    Vars: map[string]interface{}{
      "identifier":            id,
      "owner":                 owner,
      "key_name":              keyPair.Name,
      "key":                   keyPair.KeyPair.PublicKey,
      "zone":                  os.Getenv("ZONE"),
      "rke2_version":          rke2Version,
      "rancher_version":       rancherVersion,
      "file_path":             testDir,
      "aws_access_key_id":     accessKey,
      "aws_secret_access_key": secretKey,
      "aws_region":            region,
    },
    // Environment variables to set when running Terraform
    EnvVars: map[string]string{
      "AWS_DEFAULT_REGION":  region,
      "AWS_REGION":          region,
      "TF_DATA_DIR":         testDir,
      "TF_IN_AUTOMATION":    "1",
      "TF_CLI_ARGS_plan":    "-no-color -state=" + testDir + "/tfstate",
      "TF_CLI_ARGS_apply":   "-no-color -state=" + testDir + "/tfstate",
      "TF_CLI_ARGS_destroy": "-no-color -state=" + testDir + "/tfstate",
      "TF_CLI_ARGS_output":  "-no-color -state=" + testDir + "/tfstate",
    },
    RetryableTerraformErrors: util.GetRetryableTerraformErrors(),
    NoColor:                  true,
    SshAgent:                 sshAgent,
    Upgrade:                  true,
  })

  _, err = terraform.InitAndApplyE(t, terraformOptions)
  if err != nil {
    util.Teardown(t, testDir, terraformOptions, keyPair)
    os.Remove(exampleDir + ".terraform.lock.hcl")
    sshAgent.Stop()
    t.Fatalf("Error creating cluster: %s", err)
  }
  t.Log("Test passed, tearing down...")
  util.Teardown(t, testDir, terraformOptions, keyPair)
  os.Remove(exampleDir + ".terraform.lock.hcl")
  sshAgent.Stop()
}