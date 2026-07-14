package three

import (
	"os"
	"strings"
	"testing"

	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/rancher/terraform-rancher2-aws/test/fixture"
)

// This test is the same as basic but it also tests that the state is correctly stored in S3 and can be used to re-create the cluster.
func TestThreeState(t *testing.T) {
	t.Parallel()
	f := fixture.NewFixture(t, "three")
	defer f.Teardown(t)

	backendTerraformOptions, err := fixture.CreateObjectStorageBackend(t, f.TestDir, f.ID, f.Owner, f.Region)
	f.TeardownOptions = append(f.TeardownOptions, backendTerraformOptions)
	if err != nil {
		t.Log("Test failed, tearing down...")
		t.Fatalf("Error creating cluster: %s", err)
	}

	terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		TerraformDir: f.ExampleDir,
		// Variables to pass to our Terraform code using -var options
		Vars: map[string]any{
			"identifier":      f.ID,
			"owner":           f.Owner,
			"key_name":        f.KeyPair.Name,
			"key":             f.KeyPair.PublicKey,
			"zone":            os.Getenv("ZONE"),
			"rke2_version":    f.Rke2Version,
			"rancher_version": f.RancherVersion,
			"file_path":       f.TestDir,
			"acme_server_url": f.AcmeServerURL,
		},
		// Environment variables to set when running Terraform
		EnvVars: map[string]string{
			"AWS_DEFAULT_REGION":  f.Region,
			"AWS_REGION":          f.Region,
			"TF_DATA_DIR":         f.TestDir,
			"TF_PLUGIN_CACHE_DIR": f.PluginsDir,
			"TF_IN_AUTOMATION":    "1",
			"TF_CLI_ARGS_init":    "-backend-config=\"bucket=" + strings.ToLower(f.ID) + "\"",
			"TF_CLI_ARGS_plan":    "-no-color", // using remote state from storage backend
			"TF_CLI_ARGS_apply":   "-no-color -parallelism=5",
			"TF_CLI_ARGS_destroy": "-no-color",
			"TF_CLI_ARGS_output":  "-no-color",
		},
		RetryableTerraformErrors: fixture.GetRetryableTerraformErrors(),
		NoColor:                  true,
		SshAgent:                 f.SSHAgent,
		Reconfigure:              true,
		Upgrade:                  true,
	})

	f.TeardownOptions = append([]*terraform.Options{terraformOptions}, f.TeardownOptions...)

	_, err = terraform.InitAndApplyContextE(t, t.Context(), terraformOptions)
	if err != nil {
		t.Log("Test failed, tearing down...")
		fixture.GetErrorLogs(t, f.TestDir+"/kubeconfig")
		t.Fatalf("Error creating cluster: %s", err)
	}
	fixture.CheckReady(t, f.TestDir+"/kubeconfig")
	fixture.CheckRunning(t, f.TestDir+"/kubeconfig")

	t.Log("Validating remote state by destroying the local filesystem files and allowing Terraform to re-create them from S3")
	err = os.RemoveAll(f.TestDir)
	if err != nil {
		t.Log("Test failed, tearing down...")
		fixture.GetErrorLogs(t, f.TestDir+"/kubeconfig")
		t.Fatalf("Error removing test files: %s", err)
	}
	err = fixture.CreateTestDirectories(t, f.ID)
	if err != nil {
		t.Log("Test failed, tearing down...")
		fixture.GetErrorLogs(t, f.TestDir+"/kubeconfig")
		t.Fatalf("Error creating cluster: %s", err)
	}

	t.Log("Running the apply again should re-create local files from state in S3, remote AWS resources should not be touched")
	err = os.WriteFile(f.TestDir+"/id_rsa", []byte(f.KeyPair.PrivateKey), 0600)
	if err != nil {
		t.Log("Test failed, tearing down...")
		fixture.GetErrorLogs(t, f.TestDir+"/kubeconfig")
		t.Fatalf("Error creating cluster: %s", err)
	}
	_, err = terraform.InitAndApplyContextE(t, t.Context(), terraformOptions)
	if err != nil {
		t.Log("Test failed, tearing down...")
		fixture.GetErrorLogs(t, f.TestDir+"/kubeconfig")
		t.Fatalf("Error creating cluster: %s", err)
	}
	fixture.CheckReady(t, f.TestDir+"/kubeconfig")
	fixture.CheckRunning(t, f.TestDir+"/kubeconfig")

	// Running the apply again should not change anything
	_, err = terraform.InitAndApplyContextE(t, t.Context(), terraformOptions)
	if err != nil {
		t.Log("Test failed, tearing down...")
		fixture.GetErrorLogs(t, f.TestDir+"/kubeconfig")
		t.Fatalf("Error creating cluster: %s", err)
	}
	fixture.CheckReady(t, f.TestDir+"/kubeconfig")
	fixture.CheckRunning(t, f.TestDir+"/kubeconfig")

	if t.Failed() {
		t.Log("Test failed...")
	} else {
		t.Log("Test passed...")
	}
}
