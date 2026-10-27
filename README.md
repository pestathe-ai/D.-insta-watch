# D. Insta Watch

App Android che trasforma le foto di un orologio in vendita in un post Instagram pronto,
scritto con Gemini di Google (piano gratuito).

## Cosa fa
- Scegli fino a 4 foto dalla galleria o le scatti al momento.
- Inserisci i dati certi: marca, modello, referenza, anno, condizioni, corredo, prezzo, note.
- L'IA guarda le foto e scrive:
  - la didascalia di vendita (gancio iniziale, dati, descrizione, invito al DM);
  - massimo 5 hashtag;
  - 3 slide per le storie;
  - una risposta pronta per chi scrive in privato;
  - eventuali **avvisi** se le foto non tornano con i dati (es. scatola dichiarata ma non visibile).
- Puoi modificare i testi, copiarli o toccare **Copia e condividi su Instagram**:
  la didascalia viene copiata e le foto passano a Instagram, dove incolli il testo.

Referenze, anni e dati tecnici vengono presi solo da quello che scrivi tu: l'IA non li inventa.

## Primo avvio (gratis)
1. Vai su [aistudio.google.com](https://aistudio.google.com) con il tuo account Google.
2. Tocca **Get API key** → **Create API key** e copia la chiave (inizia con `AIza`).
   Non serve la carta di credito.
3. Apri l'app → Impostazioni → incolla la chiave.
4. Facoltativo: nome della pagina, città e un testo fisso da mettere in fondo a ogni post.

La chiave resta solo sul telefono e viene inviata solo a `generativelanguage.googleapis.com`.

## Da sapere sul piano gratuito
- Ci sono limiti di richieste al minuto e al giorno: per qualche post al giorno bastano.
  Se li superi l'app te lo dice; riprova più tardi o cambia modello nelle Impostazioni.
- Sul piano gratuito Google può usare testi e foto inviati per migliorare i suoi prodotti,
  e possono essere letti da revisori. Non inserire dati personali (nomi, indirizzi, telefoni dei clienti).
- Google cambia spesso i nomi dei modelli: se uno sparisce, scegline un altro nelle Impostazioni.

## Limiti
- Instagram non accetta la didascalia dalla condivisione: va incollata (è già negli appunti).
- Nessuna pubblicazione automatica: l'ultimo tocco su "Condividi" è tuo.
- I testi non vengono salvati: copia quello che ti serve prima di uscire.

## Come viene compilata
GitHub Actions genera le cartelle Android con `tool/setup_platforms.sh`, esegue analisi e test,
compila e firma l'APK, e lo pubblica nelle Releases.
