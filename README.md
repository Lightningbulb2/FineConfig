# FineConfig

A whole Guix System in one file you fill in: `config.scm`.

## Goals

- **One file, three parts.** Pinned channels, your apps (home), and the
  system. A system reconfigure applies the home too; the home can also be
  applied on its own, quickly and without sudo.
- **Everything pinned.** Each channel is fixed to one commit, so the file
  says exactly what is installed and a rebuild gives the same machine.
- **Small, fast updates.** Updating apps needs no sudo and no system
  rebuild. `guix bump` moves the pins for you and can undo them.
- **Fill in, don't rewrite.** User, device name, disks, graphics driver and
  desktop are variables at the top.

It uses three channels: Guix, [nonguix](https://gitlab.com/nonguix/nonguix)
(stock Linux kernel, firmware, NVIDIA driver, Firefox, Steam) and
[hyperguix](https://github.com/Lightningbulb2/hyperguix) (the COSMIC
desktop and `guix bump`).

## Setup

On a fresh Guix System install (UEFI):

1. Get the file. To have your changes tracked, make your own repository
   from this one first ("Use this template" on GitHub) and clone that.

   ```sh
   guix shell git -- git clone https://github.com/Lightningbulb2/FineConfig ~/FineConfig
   ln -s FineConfig/config.scm ~/config.scm
   ```

2. Edit section 1 of `~/config.scm`: user, device name, time zone, the two
   disk UUIDs (`lsblk -f`), graphics (`'mesa` or `'nvidia`), desktop
   (`'cosmic`, `'plasma` or `'gnome`) and your apps.

3. Pull the pinned channels, then apply the system and the home:

   ```sh
   guix pull -C ~/config.scm --unsafe-channel-evaluation
   hash guix
   sudo guix system reconfigure ~/config.scm
   ```

   Reboot. The very first system reconfigure may compile the kernel, since
   nonguix's substitute server only becomes trusted once this config is
   applied; to avoid that, authorize it first as described in the
   [nonguix README](https://gitlab.com/nonguix/nonguix#substitutes-for-nonguix).

`--unsafe-channel-evaluation` lets `guix pull` read the whole file rather
than an isolated channel list. That is fine for a local file you wrote.

## Usage

The app **Updates** lists the apps that have a newer version and updates
them with a click. It runs the commands below, which you can also type:

| Command | Does |
|---|---|
| `guix bump` | list channels: pinned, running and latest commit |
| `guix bump all` | move every pin to the latest commit and pull |
| `guix bump --check` | list the installed apps that have a newer version |
| `guix bump firefox` | update that app now (its channel moves; no logout) |
| `guix bump nonguix -H` | update one channel and install the result |
| `guix bump --home` | apply your edits to the apps / home part |
| `guix bump --system` | apply the system and the home (sudo) |
| `guix bump --undo -H` | go back to the pins from before the last bump |
| `guix nightly` | bump all, system + home, clean up, power off |

- A **pull** only changes which package versions are available. Nothing
  installed changes until the home or the system is applied.
- To update one program, bump the channel it comes from with `-H`. Don't
  use `guix install` or `guix upgrade`: they fill a separate profile that
  the config doesn't describe.
- Before applying new pins, `guix bump` warns if slow packages would be
  compiled for lack of a ready-made build, and asks.
- If `config.scm` is in a git repository, `guix bump` commits and pushes
  every change it pulled or applied.
- `guix bump --help` lists the rest.

## Modifying

- **Apps:** add package names to `%apps` (`guix search WORD` finds them),
  then `guix bump --home`. Steam has its own switch, `%steam?`, because it
  is built for one graphics driver.
- **Graphics or desktop:** change `%gpu`, `%nvidia-driver` or `%desktop`,
  then `guix bump --system` and reboot.
- **System services** (SSH, printing, ...): add them in `my-system` where
  the comment shows, then `guix bump --system`.
- **Per-user settings** (environment variables, dotfiles): add home
  services in `my-home`, then `guix bump --home`.
- **Another channel:** add a `(channel ...)` form to `%channels` with a
  `(commit "...")` line, then `guix bump THAT-CHANNEL`.
- **Something broke:** `guix bump --undo -S -H`, or pick an older entry in
  the boot menu and run `sudo guix system roll-back`.

## License

GPL-3.0-or-later. See `LICENSE`.
