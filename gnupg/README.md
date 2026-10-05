# OpenPGP YubiKeys

The public key is in [`public-key.asc`](public-key.asc). Its primary fingerprint is
`4305D17549D17C130E4F4FEE855E17DE1D09184F`. The primary key signs and
certifies; its subkeys encrypt and authenticate (including SSH). All three
expire on September 28, 2028. Identical private keys are stored on two
YubiKeys, not in this repository or in the computer's GnuPG home.

## Set up another computer

Install GnuPG, a suitable pinentry program, and smartcard/PC/SC support. On
Linux, `stow -t ~ gnupg` from the repository root installs the GnuPG agent
settings; on another OS, adapt `gpg-agent.conf` to the local pinentry path and
smartcard setup instead. Then, with either YubiKey inserted:

```sh
gpg --import gnupg/public-key.asc
gpg --card-status
gpg --list-secret-keys --keyid-format long
git config --file ~/.gitconfig.local user.signingkey 4305D17549D17C130E4F4FEE855E17DE1D09184F
```

`gpg --card-status` associates the public key with the inserted card; `sec>`
and `ssb>` in the secret-key listing indicate card-backed stubs, **not**
exportable private keys on the computer. The public key must be imported before
Git can sign with it. This repository's Git configuration enables signed
commits and includes `~/.gitconfig.local` for machine-specific settings; avoid
`git config --global` when `~/.gitconfig` is symlinked to the tracked dotfiles
file. Do not import a private-key backup onto another computer.

After switching between the two YubiKeys, refresh the local card stubs:

```sh
gpg --card-status
gpg-connect-agent 'SCD SERIALNO' 'LEARN --force' /bye
gpg --list-secret-keys --keyid-format long
```

`gpg --card-status` alone may leave the stubs pointing to the *previous* card;
`LEARN --force` updates them to the inserted card. If GnuPG cannot see the
card after swapping, reseat it and run `gpgconf --kill gpg-agent` before trying
again. Check the serial and fingerprints before using it. The original card
has serial `08670189`; the second has serial `20199095`. The original card's
public-key URL still points to its previous GitHub key listing; use the
repository's public key above rather than relying on a card `fetch`.

The repository's `gpg-agent.conf` enables GnuPG's SSH agent. Restart the
agent after installing it (`gpgconf --kill gpg-agent`), then set
`SSH_AUTH_SOCK` to `$(gpgconf --list-dirs agent-ssh-socket)` in a shell where
you want to use this card for SSH; `ssh-add -L` should list its public key.
`gpg --export-ssh-key 4305D17549D17C130E4F4FEE855E17DE1D09184F` prints
the public SSH key to register with SSH services. Switching from an existing
SSH agent may require loading its other identities into GnuPG or keeping that
agent for those connections. This dotfiles setup starts a separate `ssh-agent`
before loading the GPG module, so SSH does not switch to GnuPG automatically.

## Revocation and renewal

Keep the revocation certificate in Bitwarden, **not in this repository**. It
can revoke the public key if both cards are lost or compromised, but cannot
recover private keys, decrypt files, or renew expiration. In an emergency,
import the certificate with `gpg --import /path/to/revocation.asc`, export the
now-revoked public key, and publish it everywhere this key was distributed.
Never import the certificate merely to inspect it: importing is the revocation
operation.

Before September 28, 2028, use either card's primary key to renew expiration
on the primary key and both subkeys, then distribute the updated public key to
other computers and services. Renewing expiration does not require restoring a
private key to the computer, but replacing a lost card with a *third* identical
card is impossible without a private-key backup. If both cards are lost, use
the revocation certificate and generate a different key. The older key's
encryption key was overwritten on the original YubiKey; older ciphertext may
no longer be decryptable without another backup of that old key.
