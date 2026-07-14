package downstream

import (
	"os"
	"testing"

	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/rancher/terraform-rancher2-aws/test/fixture"
)

func TestDownstreamSplitrole(t *testing.T) {
	t.Parallel()
	f := fixture.NewFixture(t, "downstream")
	defer f.Teardown(t)

	accessKey := fixture.GetAwsAccessKey()
	secretKey := fixture.GetAwsSecretKey()
	sessionToken := fixture.GetAwsSessionToken()

	terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		TerraformDir: f.ExampleDir,
		// Variables to pass to our Terraform code using -var options
		Vars: map[string]any{
			"identifier":             f.ID,
			"owner":                  f.Owner,
			"key_name":               f.KeyPair.Name,
			"key":                    f.KeyPair.PublicKey,
			"zone":                   os.Getenv("ZONE"),
			"rke2_version":           f.Rke2Version,
			"rancher_version":        f.RancherVersion,
			"file_path":              f.TestDir,
			"aws_access_key_id":      accessKey,
			"aws_secret_access_key":  secretKey,
			"aws_session_token":      sessionToken,
			"aws_region":             f.Region,
			"acme_server_url":        f.AcmeServerURL,
			"downstream_node_config": "split-role-node-config",
		},
		// Environment variables to set when running Terraform
		EnvVars: map[string]string{
			"AWS_DEFAULT_REGION":  f.Region,
			"AWS_REGION":          f.Region,
			"TF_DATA_DIR":         f.TestDir,
			"TF_PLUGIN_CACHE_DIR": f.PluginsDir,
			"TF_IN_AUTOMATION":    "1",
			"KUBECONFIG":          f.TestDir + "/kubeconfig",
			"KUBE_CONFIG_PATH":    f.TestDir + "/kubeconfig",
			"TF_CLI_ARGS_plan":    "-no-color -state=" + f.TestDir + "/tfstate",
			"TF_CLI_ARGS_apply":   "-no-color -state=" + f.TestDir + "/tfstate",
			"TF_CLI_ARGS_destroy": "-no-color -state=" + f.TestDir + "/tfstate",
			"TF_CLI_ARGS_output":  "-no-color -state=" + f.TestDir + "/tfstate",
		},
		RetryableTerraformErrors: fixture.GetRetryableTerraformErrors(),
		NoColor:                  true,
		SshAgent:                 f.SSHAgent,
		Upgrade:                  true,
	})

	f.TeardownOptions = append(f.TeardownOptions, terraformOptions)

	_, err := terraform.InitAndApplyContextE(t, t.Context(), terraformOptions)
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
