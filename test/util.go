// Package test provides utility functions and common fixtures for the test suite.
package test

import (
	"context"
	"fmt"
	"os"
	"path/filepath"
	"strings"
	"testing"

	"github.com/gruntwork-io/terratest/modules/random"
	"github.com/gruntwork-io/terratest/modules/shell"
)

// GetRetryableTerraformErrors returns a map of Terraform errors that should be retried.
func GetRetryableTerraformErrors() map[string]string {
	return map[string]string{
		// The reason is unknown, but eventually these succeed after a few retries.
		".*unable to verify signature.*":             "Failed due to transient network error.",
		".*unable to verify checksum.*":              "Failed due to transient network error.",
		".*no provider exists with the given name.*": "Failed due to transient network error.",
		".*registry service is unreachable.*":        "Failed due to transient network error.",
		".*connection reset by peer.*":               "Failed due to transient network error.",
		".*TLS handshake timeout.*":                  "Failed due to transient network error.",
		".*context deadline exceeded.*":              "Failed due to kubernetes timeout, retrying.",
		".*http2: client connection lost.*":          "Failed due to transient network error.",
	}
}

// SetAcmeServer sets the ACME server URL environment variable if not already set.
func SetAcmeServer(t *testing.T) string {
	acmeserver := os.Getenv("ACME_SERVER_URL")
	if acmeserver == "" {
		t.Setenv("ACME_SERVER_URL", "https://acme-staging-v02.api.letsencrypt.org/directory")
		acmeserver = "https://acme-staging-v02.api.letsencrypt.org/directory"
	}
	return acmeserver
}

// GetRegion retrieves the AWS region from environment variables, defaulting to us-west-2.
func GetRegion() string {
	region := os.Getenv("AWS_REGION")
	if region == "" {
		region = os.Getenv("AWS_DEFAULT_REGION")
	}
	if region == "" {
		region = "us-west-2"
	}
	return region
}

// GetAwsAccessKey retrieves the AWS access key from the environment.
func GetAwsAccessKey() string {
	key := os.Getenv("AWS_ACCESS_KEY_ID")
	if key == "" {
		key = "FAKE123-ABC"
	}
	return key
}

// GetAwsSecretKey retrieves the AWS secret key from the environment.
func GetAwsSecretKey() string {
	secret := os.Getenv("AWS_SECRET_ACCESS_KEY")
	if secret == "" {
		secret = "FAKE123-ABC"
	}
	return secret
}

// GetAwsSessionToken retrieves the AWS session token from the environment.
func GetAwsSessionToken() string {
	return os.Getenv("AWS_SESSION_TOKEN")
}

// GetID generates a unique identifier for test resources.
func GetID() string {
	id := os.Getenv("IDENTIFIER")
	if id == "" {
		id = random.UniqueID()
	}
	id += "-" + random.UniqueID()
	return id
}

// GetRepoRoot returns the absolute path to the repository root directory.
func GetRepoRoot(ctx context.Context, t *testing.T) string {
	cmd := shell.Command{
		Command: "bash",
		Args:    []string{"../scripts/get_repo_root.sh"},
	}
	out, err := shell.RunCommandContextAndGetOutputE(t, ctx, &cmd)
	if err != nil {
		t.Fatalf("Error getting git root directory: %v", err)
	}
	return strings.TrimSpace(out)
}

// CreateTestDirectories sets up the necessary directory structure for tests.
func CreateTestDirectories(ctx context.Context, t *testing.T, id string) error {
	gwd := GetRepoRoot(ctx, t)
	fwd, err := filepath.Abs(gwd)
	if err != nil {
		return fmt.Errorf("getting absolute path for repo root: %w", err)
	}
	paths := []string{
		filepath.Join(fwd, "test/data"),
		filepath.Join(fwd, "test/data", id),
		filepath.Join(fwd, "test/data", id, "backend"),
		filepath.Join(fwd, "test/data", id, "data"),
		filepath.Join(fwd, "test/data", id, "plugins"),
	}
	for _, path := range paths {
		err = os.Mkdir(path, 0750)
		if err != nil && !os.IsExist(err) {
			return fmt.Errorf("creating directory %s: %w", path, err)
		}
	}
	return nil
}
