# To learn more about how to use Nix to configure your environment
# see: https://firebase.google.com/docs/studio/customize-workspace
{ pkgs, ... }: {
  # Which nixpkgs channel to use.
  channel = "stable-24.05"; # or "unstable"

  # Use https://search.nixos.org/packages to find packages
  packages = [
    pkgs.python311
    pkgs.python311Packages.pip
    pkgs.flutter
  ];

  # Sets environment variables in the workspace
  env = {};
  idx = {
    # Search for the extensions you want on https://open-vsx.org/ and use "publisher.id"
    extensions = [
      "dart-code.dart-code"
      "dart-code.flutter"
    ];

    # Enable previews
    previews = {
      enable = true;
      previews = {
        web = {
          command = ["python" "-m" "http.server" "$PORT"];
          manager = "web";
        };
      };
    };

    # Workspace lifecycle hooks
    workspace = {
      # Runs when a workspace is first created
      onCreate = {
        install-dependencies = "pip install -r requirements.txt";
      };
      # Runs when the workspace is (re)started
      onStart = {
        start-backend = "uvicorn main:app --host 0.0.0.0 --port 8000";
      };
    };
  };
}
