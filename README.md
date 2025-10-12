NixOS deployment for 'A digital knowledge infrastructure to provide information on scientific videos and podcasts'

see https://github.com/xEatos/dashboardduck

This is starting a local dev container but a later version of this is meant to be deployed in production.


Start the local container
=========================

This has only been tested on a NixOS host, so far. It should work on any Linux host if you install Nix
(e.g. `apt install nix` or use the official installer) and have the nixos-container command available
(e.g. install with `nix-env` or in `nix-shell`). That part has not been tested, yet, so we suggest that you
use a NixOS host, for now.

Start the container:

1. Enable support Nix flakes, see https://nixos.wiki/wiki/Flakes
2. `sudo ./run-container.sh`
    - It will create or update the container `borg-dev`.
    - It will configure the container to use the network namespace of the host so you can directly access
      its services.
    - It will start the container if it isn't already running.
    - You can later use the same command to apply changes to the container. It will automatically restart
      services inside the container when necessary.
3. Obtain a root shell in the container: `sudo nixos-container root-login borg-dev`
4. Only for the dev container: Add your ngrok token (see below) and then restart the container.
5. You can control the container with `nixos-container` and via the systemd service `container@borg-dev.service`.


Add your ngrok token
====================

We use the ngrok service to provide HTTPS for the local test server:
Create an account and then create the following files in the dev container:
1. Create an account: https://dashboard.ngrok.com/get-started/setup/
2. Run the authtoken command (2nd step of the setup instructions):
   `ngrok config add-authtoken ...`
3. Write the dev domain into the file `/root/ngrok-domain.txt`
  (without any trailing slash)


How to update the software
==========================

This repository contains exact references to all the software that is used. If you run it again at a later time,
it will not automatically update. This also means that you can downgrade to an earlier version by checking out
an earlier version of this repository (assuming that there aren't any incompatible database changes, of course).

Here is what you should do if you do want a newer version.

Update the system
-----------------

1. Optional: Change `nixpkgs.url` in `flake.nix` to point to a newer release.
2. Update package definitions: `nix flake update nixpkgs --commit-lock-file`
3. Update the container: `sudo ./run-container.sh`
4. If there are any warnings about changed or deprecated options, fix them before the next release (i.e. within half a year).

Update dashboardduck
--------------------

1. Optional: Update pinned versions in `pnpm-lock.yaml` in the repository of dashboardduck.
2. Update the flake input: `nix flake update dashboardduck --commit-lock-file`
3. Remove the line `hash = ...` in `pkgs/dashboardduck/dashboardduck.nix` (or add `#` to turn it into a comment).
4. Build it: `nix build .#dashboardduck`
5. It will fail and tell you the new hash. Put that hash into the `hash = ...` line.
6. Update the container: `sudo ./run-container.sh`

Update integrationindri
-----------------------

1. Optional: Update pinned versions in requirements.txt in the repository of integrationindri.
2. Update the flake input: `nix flake update integrationindri --commit-lock-file`
3. Update Python dependencies: `nix run .#updateIntegrationindriDeps`
4. Optional: Review and commit and changes that the update did in `pkgs/integrationindri/python-packages.nix`
5. Update the container: `sudo ./run-container.sh`

Update searchsnail
------------------

1. Optional: Update pinned versions in `build.gradle.kts` in the repository of searchsnail.
2. Update the flake input: `nix flake update searchsnail --commit-lock-file`
3. Update Java dependencies: `nix run .#updateSearchsnailDeps`
4. Optional: Review and commit and changes that the update did in `pkgs/searchsnail/searchsnail-deps.json`
5. Update the container: `sudo ./run-container.sh`

Additional information
----------------------

- If you want to update multiple components, feel free to combine the steps, e.g. `nix flake update` and `run-container.sh`.
- If you want to update the software without pushing it to Github, you can point the flake input to a local repository.
  For example: `nix flake update --override-input searchsnail /path/to/local/searchsnail`

