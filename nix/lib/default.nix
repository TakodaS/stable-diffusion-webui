{ lib, ... }:
{
  forAllSystems = lib.genAttrs lib.systems.flakeExposed;
}
