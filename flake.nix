{
  description = "The gleative nix template.";
  outputs = { self }: {
    templates = {
      default = {
        path = ./template;
        description = "A simple setup of gleative.";
      };
    };
  };
}
