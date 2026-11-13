;;; FineConfig --- a one-file Guix System configuration
;;;
;;; Fill in section 1, then see README.md.  One file holds three things;
;;; Guix reads the one that matches the command (end of the file):
;;;
;;;   channels   guix pull -C config.scm --unsafe-channel-evaluation
;;;   home       guix home reconfigure config.scm          (your apps; no sudo)
;;;   system     sudo guix system reconfigure config.scm   (kernel, drivers,
;;;                                                         services, desktop)
;;;
;;; Day to day, `guix bump' does this for you: see README.md.

(use-modules (gnu)
             (gnu home)
             (gnu home services desktop)
             (gnu home services guix)
             (gnu home services sound)
             (gnu services dbus)
             (gnu services desktop)
             (gnu services sddm)
             (gnu services xorg)
             (guix channels)
             (ice-9 match)
             (srfi srfi-1))


;;; =========================================================================
;;; 1. FILL THIS IN
;;; =========================================================================

(define %user      "me")                ;login name
(define %full-name "Me")
(define %host-name "mycomputer")        ;device name
(define %timezone  "America/New_York")  ;a tz database name
(define %locale    "en_US.utf8")
(define %keyboard  "us")

;; Disks: run `lsblk -f' and copy the UUID of each partition.
(define %root-uuid "00000000-0000-0000-0000-000000000000")
(define %root-type "btrfs")             ;"btrfs" or "ext4"
(define %efi-uuid  "0000-0000")         ;the EFI partition, mounted at /boot/efi

;; Graphics: 'nvidia for an NVIDIA card with NVIDIA's own driver;
;; 'mesa for everything else (AMD, Intel, virtual machines).
(define %gpu 'mesa)
;; NVIDIA only.  Driver: nvda (the default, long-lived branch),
;; nvda-new-feature, nvda-beta, or a legacy branch: nvda-470, nvda-390.
;; The open kernel module works from the RTX 20 / GTX 16 series on and is
;; required from the RTX 50 series on.
(define %nvidia-driver       'nvda)
(define %nvidia-open-module? #t)

;; Desktop: 'cosmic, 'plasma or 'gnome.
(define %desktop 'cosmic)

;; Your apps, by package name (find names with `guix search WORD').  These
;; go in the home environment: changing the list only needs
;; `guix bump --home'.
(define %apps
  '("firefox" "git" "libreoffice" "flatpak"
    "font-google-noto" "font-google-noto-emoji"))

;; Steam is built for one graphics driver, so it gets a switch of its own.
(define %steam? #f)

;; Programs every user and root should have.
(define %system-apps
  '("gnome-keyring"))


;;; =========================================================================
;;; 2. CHANNELS: where packages come from, each pinned to one commit
;;; =========================================================================
;;; Don't edit the pins by hand: `guix bump CHANNEL' (or `all') moves them
;;; to the latest commit and pulls; `guix bump' alone lists them.

(define %channels
  (list (channel
          (name 'guix)
          (url "https://codeberg.org/guix/guix.git")
          (branch "master")
          (commit "e2a7a34ed7c396c094bb7606b7112ad548c4ef3a")
          (introduction
           (make-channel-introduction
            "9edb3f66fd807b096b48283debdcddccfea34bad"
            (openpgp-fingerprint
             "BBB0 2DDF 2CEA F6A8 0D1D E643 A2A0 6DF2 A33A 54FA"))))
        ;; Non-free software: the stock Linux kernel and firmware, NVIDIA's
        ;; driver, Firefox, Steam.
        (channel
          (name 'nonguix)
          (url "https://gitlab.com/nonguix/nonguix")
          (branch "master")
          (commit "57b156aa003e2b6eacf979cac377e4b585bf3a19")
          (introduction
           (make-channel-introduction
            "897c1a470da759236cc11798f4e0a5f7d4d59fbc"
            (openpgp-fingerprint
             "2A39 3FFF 68F4 EF7A 3D29 12AF 6F51 20A0 22FB B2D5"))))
        ;; The COSMIC desktop and `guix bump'.
        (channel
          (name 'hyperguix)
          (url "https://github.com/Lightningbulb2/hyperguix.git")
          (branch "main")
          (commit "8003b3a0a8306f2b23d4a46698d0b543280df641"))))


;;; =========================================================================
;;; Helpers
;;; =========================================================================
;;; Packages are looked up by name when the home or system is built, never
;;; while `guix pull' reads this file: the Guix doing the pull may not have
;;; the channels above yet.

(define (app name)
  (specification->package name))

(define (from module name)
  ;; The variable NAME of MODULE, for what has no package name of its own.
  (module-ref (resolve-interface module) name))

(define (nvidia?)
  (eq? %gpu 'nvidia))

(define (graphics-driver)
  (if (nvidia?)
      (from '(nongnu packages nvidia) %nvidia-driver)
      (app "mesa")))

(define (with-graphics-driver x)
  ;; X is the operating system or the home environment.  For NVIDIA, add the
  ;; driver's kernel module and service (system only) and build every
  ;; package against the driver instead of Mesa.
  (if (nvidia?)
      (((from '(nonguix transformations) 'nonguix-transformation-nvidia)
        #:driver (graphics-driver)
        #:open-source-kernel-module? %nvidia-open-module?
        ;; Xorg-based login screens need the driver in their Xorg.
        #:configure-xorg? (match %desktop
                            ('plasma sddm-service-type)
                            ('gnome  #t)
                            (_       #f)))
       x)
      x))


;;; =========================================================================
;;; 3. HOME: your apps and per-user settings
;;; =========================================================================
;;; Applied by `guix home reconfigure' / `guix bump --home': no sudo, in
;;; effect at once.  Not part of the system: a system reconfigure leaves it
;;; alone.

(define (my-home)
  (home-environment
    (packages
     (append (map app (cons "guix-bump" %apps))
             (if %steam?
                 (list ((from '(nongnu packages game-client) 'steam-for)
                        (graphics-driver)))
                 '())))
    (services
     (list (service home-dbus-service-type)
           (service home-pipewire-service-type)     ;sound, screen sharing
           ;; ~/.config/guix/channels.scm: the pins, for a plain `guix pull'.
           (service home-channels-service-type %channels)
           ;; More per-user settings go here, for example:
           ;; (simple-service 'my-variables
           ;;                 home-environment-variables-service-type
           ;;                 '(("EDITOR" . "nano")))
           ))))


;;; =========================================================================
;;; 4. SYSTEM: kernel, drivers, services, desktop
;;; =========================================================================
;;; Applied by `sudo guix system reconfigure' / `guix bump --system'.
;;; Kernel and driver changes need a reboot.

(define (desktop-services)
  (match %desktop
    ('plasma (list (service plasma-desktop-service-type)
                   (service sddm-service-type)))
    ('gnome  (list (service gnome-desktop-service-type))) ;GDM is a default
    ('cosmic
     ;; COSMIC's login screen and screen locker, cosmic-greeter, run by
     ;; greetd.  It needs its own user, PAM service and D-Bus policy.
     (let ((greeter (app "cosmic-greeter")))
       (list (service greetd-service-type
                      (greetd-configuration
                       (terminals
                        (list (greetd-terminal-configuration
                               (terminal-vt "7")
                               (terminal-switch #t)
                               (default-session-user "cosmic-greeter")
                               (default-session-command
                                (file-append greeter
                                             "/bin/cosmic-greeter-start")))))))
             (simple-service 'cosmic-greeter-pam pam-root-service-type
                             (list (unix-pam-service "cosmic-greeter")))
             (simple-service 'cosmic-greeter-account account-service-type
                             (list (user-group (name "cosmic-greeter")
                                               (system? #t))
                                   (user-account
                                    (name "cosmic-greeter")
                                    (group "cosmic-greeter")
                                    (supplementary-groups '("video"))
                                    (system? #t)
                                    (home-directory "/var/lib/cosmic-greeter")
                                    (shell (file-append (app "shadow")
                                                        "/sbin/nologin")))))
             (simple-service 'cosmic-greeter-run-directory
                             activation-service-type
                             #~(let ((user (false-if-exception
                                            (getpwnam "cosmic-greeter"))))
                                 (unless (file-exists? "/run/cosmic-greeter")
                                   (mkdir "/run/cosmic-greeter"))
                                 (when user
                                   (chown "/run/cosmic-greeter"
                                          (passwd:uid user)
                                          (passwd:gid user)))))
             (simple-service 'cosmic-greeter-dbus dbus-root-service-type
                             (list greeter)))))))

(define (base-services)
  ;; Guix's standard desktop services (network, sound, power, ...), with
  ;; nonguix's substitute server so its packages are downloaded instead of
  ;; compiled, and the pins in /etc/guix/channels.scm.
  (modify-services
      (if (eq? %desktop 'gnome)
          %desktop-services
          ;; GDM is GNOME's login screen; the others bring their own.
          (remove (lambda (service)
                    (eq? (service-kind service) gdm-service-type))
                  %desktop-services))
    (guix-service-type
     config =>
     (guix-configuration
      (inherit config)
      (channels %channels)
      (substitute-urls (cons "https://substitutes.nonguix.org"
                             %default-substitute-urls))
      (authorized-keys
       (cons (plain-file "nonguix.pub" "\
(public-key
 (ecc
  (curve Ed25519)
  (q #C1FD53E5D4CE971933EC50C9F307AE2171A2D3B52C804642A7A35F84F3A4EA98#)))")
             %default-authorized-guix-keys))))))

(define (my-system)
  (operating-system
    (host-name %host-name)
    (timezone %timezone)
    (locale %locale)
    (keyboard-layout (keyboard-layout %keyboard))

    ;; The stock Linux kernel with all firmware and CPU microcode (nonguix).
    (kernel (from '(nongnu packages linux) 'linux))
    (initrd (from '(nongnu system linux-initrd) 'microcode-initrd))
    (firmware (cons (from '(nongnu packages linux) 'linux-firmware)
                    %base-firmware))

    (bootloader (bootloader-configuration
                  (bootloader grub-efi-bootloader)
                  (targets (list "/boot/efi"))
                  (keyboard-layout keyboard-layout)))

    (file-systems (cons* (file-system
                           (mount-point "/")
                           (device (uuid %root-uuid))
                           (type %root-type))
                         (file-system
                           (mount-point "/boot/efi")
                           (device (uuid %efi-uuid 'fat))
                           (type "vfat"))
                         %base-file-systems))

    ;; `wheel' is what allows sudo.
    (users (cons (user-account
                   (name %user)
                   (comment %full-name)
                   (group "users")
                   (home-directory (string-append "/home/" %user))
                   (supplementary-groups '("wheel" "netdev" "audio" "video")))
                 %base-user-accounts))

    (packages (append (map app %system-apps)
                      ;; COSMIC goes in the system profile so the login
                      ;; screen finds its session.
                      (if (eq? %desktop 'cosmic)
                          (list (app "cosmic") (app "cosmic-greeter"))
                          '())
                      %base-packages))

    (services (append (desktop-services)
                      ;; More system services go here, for example:
                      ;; (list (service openssh-service-type)
                      ;;       (service cups-service-type))   ;printing
                      ;; with (use-service-modules ssh cups) at the top.
                      (base-services)))))


;;; =========================================================================
;;; What Guix gets from this file
;;; =========================================================================

(match (command-line)
  ((_ (or "pull" "time-machine") . _) %channels)
  ((_ "home" . _)                     (with-graphics-driver (my-home)))
  (_                                  (with-graphics-driver (my-system))))
