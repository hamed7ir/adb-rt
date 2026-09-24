# Signing — mandatory on Windows RT, not a fallback

> ## ⛔ On Windows RT there is no unsigned install. None.
>
> **Measured on the Surface RT, repeatedly, with test-signing already ON:** an unsigned INF is
> **refused outright** —
>
> ```
> The third-party INF does not contain digital signature information.
> ```
>
> There is **no "Install this driver software anyway" option** on RT. That prompt exists on
> desktop Windows; it is not offered here. An earlier revision of this file predicted a
> warning-you-could-click-past and said unsigned would probably be enough. **That prediction
> was wrong and has been removed** — the device disproved it.

## Three conditions, and all three are required together

Any one of them missing and the install fails.

| | condition | why |
|---|---|---|
| **1** | **test-signing ON** on the target device | see below — it does not do what the name suggests |
| **2** | the INF **signed with a catalog** (`.cat`) | RT checks the package signature, and the INF's `CatalogFile=` line points at it |
| **3** | the signing certificate imported into **Trusted Root**  (**Trusted Publishers** optional) on that device | a signature is only worth the trust anchor behind it |

### ⚠ Test-signing does not disable signature checking

This is the part that costs an afternoon. Turning test-signing on does **not** mean "stop
checking signatures". It means **"accept a chain that ends at a root this machine's owner
installed, instead of requiring one that ends at Microsoft."**

Two consequences, both observed:

- Test-signing **on**, package **unsigned** → still refused. There is no chain to check at all.
  That is the measurement quoted above.
- Test-signing **off**, package **self-signed** → also refused, however correctly it is signed.
  The chain ends somewhere Windows has no reason to trust.

So 1 and 3 are two halves of one idea — *let this machine trust this root* and *this machine
now trusts this root* — and 2 supplies the thing for them to act on.

## The route that actually worked — PowerShell, no WDK

**`Inf2Cat` is WDK-only, and `makecat` was not present on the build machine.** Those are the
two tools every older guide reaches for, and neither was available. Recorded here because it is
an hour nobody else needs to spend.

What worked is in-box PowerShell. On the **build machine**:

```powershell
# 1. a self-signed code-signing certificate
$cert = New-SelfSignedCertificate `
          -Type CodeSigningCert `
          -Subject "CN=adb-rt" `
          -CertStoreLocation Cert:\CurrentUser\My

# 2. a catalog covering the INF.
#    -CatalogVersion 2 is SHA-256. Version 1 is SHA-1 and is not acceptable to a modern check.
New-FileCatalog -Path .\driver `
                -CatalogFilePath .\driver\adb-rt-winusb.cat `
                -CatalogVersion 2

# 3. sign the catalog
Set-AuthenticodeSignature -FilePath .\driver\adb-rt-winusb.cat -Certificate $cert

# 4. export the public half to carry to the device
Export-Certificate -Cert $cert -FilePath .\adb-rt.cer
```

Then on the **target device**, as administrator:

```
certutil -addstore -f Root             adb-rt.cer
certutil -addstore -f TrustedPublisher adb-rt.cer
```

`Root` is the required one — it answers "is this chain anchored in something I trust?".
`TrustedPublisher` is optional and only suppresses the separate publisher prompt.

And test-signing itself, which needs a reboot to take effect:

```
bcdedit -set TESTSIGNING ON
```

## Regenerate the catalog after *any* INF change

The INF declares `CatalogFile = adb-rt-winusb.cat`, and the catalog carries a SHA-256 hash of
the INF **as it will actually be installed**. Re-running `make-inf.sh` changes the INF, so the
catalog must be rebuilt and re-signed afterwards. A catalog that hashes a previous revision
fails with the same message as no catalog at all — which reads like the signing never worked,
when in fact it worked on the wrong bytes.

## This is a user-signed package, and that is the honest framing

Nothing here is a Microsoft-signed driver, and nothing here loads a kernel binary: `winusb.sys`
is already in-box on RT 8.1 and already Microsoft-signed. What gets signed is the **INF**, so
Windows will let it bind that existing, already-trusted driver to an interface that currently
has none. The certificate is one the device's owner created and chose to trust on their own
device — anyone following this is making that same choice for their own machine.
