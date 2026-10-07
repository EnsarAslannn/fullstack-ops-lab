"""Publish one application image from a successful main CI run; never print credentials."""
from pathlib import Path
import os
import re
import subprocess
import sys
import tempfile

CONTEXTS = {"api": "src/backend/FullStackOpsLab.Api", "frontend": "src/frontend"}


class PublishingError(Exception):
    """Only fixed, secret-free diagnostic messages are allowed."""


def docker(args, environment, login_input=None):
    try:
        result = subprocess.run(["docker", *args], input=login_input, capture_output=True,
                                text=True, encoding="utf-8", errors="replace",
                                env=environment, timeout=600 if args[0] == "build" else 180)
    except (OSError, subprocess.TimeoutExpired):
        raise PublishingError("Docker command failed to start or exceeded its timeout.") from None
    if result.returncode != 0:
        # External stdout/stderr can contain credentials; never forward them.
        raise PublishingError("Docker " + args[0] + " failed (exit " + str(result.returncode) + ").")
    return result.stdout.strip()


def publish(component, environment):
    if environment.get("GITHUB_EVENT_NAME") != "push" or environment.get("GITHUB_REF") != "refs/heads/main":
        raise PublishingError("Publishing requires a main push; pull requests and other refs are rejected.")
    repository = environment.get("GITHUB_REPOSITORY", "")
    sha = environment.get("GITHUB_SHA", "")
    registry_credential = environment.get("GHCR_TOKEN", "")
    actor = environment.get("GITHUB_ACTOR", "")
    if component not in CONTEXTS or not re.fullmatch(r"[A-Za-z0-9-]+/[A-Za-z0-9_.-]+", repository):
        raise PublishingError("Publishing component or repository is invalid.")
    if not re.fullmatch(r"[0-9a-f]{40}", sha) or not registry_credential.strip() or not actor:
        raise PublishingError("Publishing requires a full commit SHA, actor and workflow token.")
    temp_root = Path(environment.get("RUNNER_TEMP", "")).resolve()
    if not environment.get("RUNNER_TEMP") or not temp_root.is_dir():
        raise PublishingError("Publishing requires an existing runner temporary directory.")

    image = "ghcr.io/" + repository.split("/")[0].lower() + "/fullstack-ops-lab-" + component
    sha_tag, latest = image + ":sha-" + sha, image + ":latest"
    docker_env = dict(environment)
    docker_env.pop("GHCR_TOKEN", None)
    with tempfile.TemporaryDirectory(prefix="fullstack-ops-ghcr-", dir=temp_root) as auth_directory:
        # Verify the owned cleanup path before TemporaryDirectory's recursive cleanup.
        if Path(auth_directory).resolve().parent != temp_root:
            raise PublishingError("Unsafe Docker auth cleanup path.")
        docker_env["DOCKER_CONFIG"] = auth_directory
        try:
            docker(["login", "ghcr.io", "--username", actor, "--password-stdin"], docker_env, registry_credential)
            docker(["build", "--platform", "linux/amd64",
                    "--label", "org.opencontainers.image.source=https://github.com/" + repository,
                    "--label", "org.opencontainers.image.revision=" + sha,
                    "--tag", sha_tag, CONTEXTS[component]], docker_env)
            built_id = docker(["image", "inspect", sha_tag, "--format", "{{.Id}}"], docker_env)
            if not re.fullmatch(r"sha256:[0-9a-f]{64}", built_id):
                raise PublishingError("Built image identity was not available.")
            docker(["push", sha_tag], docker_env)
            candidates = docker(["image", "inspect", sha_tag, "--format", "{{range .RepoDigests}}{{println .}}{{end}}"], docker_env).splitlines()
            digest_ref = next((value for value in candidates if re.fullmatch(re.escape(image) + r"@sha256:[0-9a-f]{64}", value)), None)
            if not digest_ref:
                raise PublishingError("Published image digest was not available.")
            docker(["pull", digest_ref], docker_env)
            pulled_id = docker(["image", "inspect", digest_ref, "--format", "{{.Id}}"], docker_env)
            revision = docker(["image", "inspect", digest_ref, "--format", '{{index .Config.Labels "org.opencontainers.image.revision"}}'], docker_env)
            if pulled_id != built_id or revision != sha:
                raise PublishingError("Published image identity or source revision verification failed.")
            # Advance the moving alias only after the SHA image has passed registry roundtrip checks.
            docker(["tag", digest_ref, latest], docker_env)
            docker(["push", latest], docker_env)
        finally:
            try:
                docker(["logout", "ghcr.io"], docker_env)
            except PublishingError:
                # The owned auth directory is removed regardless of logout failure.
                pass

    message = "Published " + sha_tag + " and latest; verified digest " + digest_ref + "\n"
    print(message, end="")
    summary = environment.get("GITHUB_STEP_SUMMARY")
    if summary:
        with open(summary, "a", encoding="utf-8") as output:
            output.write("### GHCR " + component + "\n\n- Source: `" + sha + "`\n- Image: `" + sha_tag + "`\n- Digest: `" + digest_ref + "`\n- Registry pull/image ID/revision: PASS\n\n")


def main(arguments=None, environment=None):
    arguments = sys.argv[1:] if arguments is None else arguments
    try:
        if len(arguments) != 1:
            raise PublishingError("Publishing requires exactly one component: api or frontend.")
        publish(arguments[0], dict(os.environ) if environment is None else environment)
        return 0
    except PublishingError as error:
        print("Publishing failed: " + str(error), file=sys.stderr)
        return 1
    except Exception:
        print("Publishing failed: unexpected error; external output withheld.", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
