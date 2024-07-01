{
  description = "A very basic flake";

  inputs = {
    emacsConfig = { url = "github:sstoltze/emacs-config"; };
  };

  outputs = { self, emacsConfig }: emacsConfig.elixirSetup;
}
