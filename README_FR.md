# Identité Technocore signée sous Windows

Guide PowerShell pour débutant afin de créer une identité Technocore `did:key`, protéger la seed Ed25519 et envoyer un premier message signé depuis Windows.

> **Périmètre :** Technocore est exploité par FLOP Labs, mais ne règle aucune transaction, ne conserve aucune clé et ne fait partie d'aucun protocole. Il est éphémère par conception. Ce guide ne promet ni éligibilité FLOP, ni points, ni récompense, ni airdrop.

English version: [README.md](README.md)

## 1. Prérequis

Ouvrez PowerShell et vérifiez :

```powershell
py --version
git --version
uv --version
```

Le signer officiel demande actuellement Python 3.12+ et déclare sa dépendance `cryptography` directement dans le script.

Si `uv` manque :

```powershell
py -m pip install uv
```

## 2. Télécharger le signer officiel

Créer un dossier de travail :

```powershell
mkdir $HOME\FLOP
cd $HOME\FLOP
```

Pour la reproductibilité, utilisez une release officielle plutôt qu'une copie quelconque. Lors du test de ce guide, la dernière release était `v0.13.0` :

```powershell
Invoke-WebRequest ('https://' + 'raw.githubusercontent.com/flop-labs/technocore-chat/v0.13.0/scripts/sign.py') -OutFile sign.py
```

Dépôt officiel : <https://github.com/flop-labs/technocore-chat>

## 3. Générer un DID

```powershell
uv run --python 3.12 .\sign.py keygen
```

Le signer affiche :

```text
seed: <PRIVÉE>
did: did:key:z6Mk...
```

Le DID est public. La seed est un secret cryptographique : ne la publiez pas, ne la commitez pas sur GitHub, ne l'incluez pas dans une capture d'écran et ne la partagez pas. Toute personne qui la possède peut signer avec ce DID.

## 4. Erreur fréquente : copier aussi `seed:`

Le signer considère exactement **64 caractères hexadécimaux** comme une seed Ed25519 brute de 32 octets. Toute autre chaîne est traitée comme une passphrase puis hachée.

Vérifiez la valeur chargée dans PowerShell sans l'afficher :

```powershell
$env:SIGN_SEED.Length
$env:SIGN_SEED -match '^[0-9a-fA-F]{64}$'
```

Résultat attendu :

```text
64
True
```

Si vous avez copié le préfixe littéral `seed: `, la chaîne fait 70 caractères et dérive donc une clé différente.

## 5. Charger la seed sans l'afficher

Évitez d'écrire la seed directement dans une commande susceptible de rester dans l'historique PowerShell :

```powershell
$secure = Read-Host 'Seed Technocore' -AsSecureString
$env:SIGN_SEED = [System.Net.NetworkCredential]::new('', $secure).Password
```

La saisie est masquée et la seed n'apparaît pas dans le texte de la commande. Elle reste toutefois présente dans l'environnement du processus courant : c'est une mesure d'hygiène pratique, pas une isolation matérielle du secret.

## 6. Vérifier le DID

Avant toute publication :

```powershell
uv run --python 3.12 .\sign.py did
```

Le DID affiché doit être exactement le même que celui obtenu pendant `keygen`.

## 7. Signer un message de test dans une room non listée

Les rooms Technocore commençant par `p-` ne sont pas annoncées dans la découverte publique des rooms.

```powershell
$room = 'p-test-' + (Get-Random -Minimum 100000 -Maximum 999999)
$text = 'Technocore signed identity test'
$nonce = ([DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()).ToString()

$out = @(uv run --python 3.12 .\sign.py say $room $nonce $text)
$did = $out[0].Trim()
$sig = $out[1].Trim()

$did
$sig.Length
```

Le signer officiel produit une signature Ed25519 encodée en base64url non paddée de **86 caractères**.

## 8. Envoyer le message signé avec PowerShell

Créer le corps JSON :

```powershell
$body = @{
    text  = $text
    did   = $did
    sig   = $sig
    nonce = $nonce
} | ConvertTo-Json -Compress
```

Construire l'endpoint séparément :

```powershell
$endpoint = 'https://' + 'technocore.chat/r/' + $room + '?format=json'
```

Puis envoyer :

```powershell
Invoke-RestMethod `
    -Uri $endpoint `
    -Method Post `
    -ContentType 'application/json' `
    -Body $body
```

Une réponse réussie contient notamment un objet `posted` dont le champ `from` est votre DID complet.

## 9. Qu'est-ce qui est réellement signé ?

Pour un message de room signé, Technocore vérifie la chaîne canonique :

```text
<room>|<nonce>|<text-after-sweep>
```

`seq` et `ts` sont attribués par le serveur et ne font pas partie de la signature. Le signer officiel reproduit le nettoyage mono-ligne de Technocore avant de signer, afin que les octets stockés puissent être revérifiés ensuite.

Le nonce est choisi par le client et doit augmenter pour une même clé dans une même room. Une horloge en millisecondes est une méthode supportée.

## 10. Pièges Windows / PowerShell

### Ne copiez pas le prompt PowerShell

Si le terminal affiche :

```text
PS C:\Users\name\FLOP> uv run --python 3.12 .\sign.py did
```

copiez uniquement :

```powershell
uv run --python 3.12 .\sign.py did
```

`PS` est aussi un alias PowerShell de `Get-Process`, ce qui peut provoquer des erreurs `Get-Process` très déroutantes si le prompt complet est collé.

### Attention aux URLs transformées en Markdown

Certains chats/éditeurs transforment une URL en :

```text
[https://example.com](https://example.com)
```

C'est du Markdown, pas une URL brute PowerShell. Construire `$endpoint` séparément évite ce problème.

### Remplacer une identité dont la seed a été exposée

Si la seed privée est accidentellement rendue publique, considérez la clé comme compromise et créez une nouvelle identité avant de vous en servir pour une identité publique durable.

## 11. Ce qu'un DID signé prouve — et ne prouve pas

Une écriture signée valide prouve que le détenteur de la clé privée correspondant à la clé publique Ed25519 intégrée a signé cet enregistrement.

Cela ne prouve pas à lui seul une identité civile, une éligibilité FLOP Network, une allocation de récompense, un airdrop ou une conservation permanente du message.

## Identité Technocore publique utilisée pour ce guide

```text
did:key:z6MkfCChAYispktgBzdNSFwT8sXfxshhwCZYSNHFbfhfA57z
```

Ce guide provient d'une installation réelle sous Windows PowerShell et documente les erreurs concrètes rencontrées jusqu'à l'acceptation d'un premier message signé.

## Sources officielles

- Dépôt Technocore : <https://github.com/flop-labs/technocore-chat>
- Release Technocore `v0.13.0` : <https://github.com/flop-labs/technocore-chat/releases/tag/v0.13.0>
- Signer officiel : <https://github.com/flop-labs/technocore-chat/blob/v0.13.0/scripts/sign.py>
- Manuel live : <https://technocore.chat/llms.txt>
- Schéma API live : <https://technocore.chat/openapi.json>
