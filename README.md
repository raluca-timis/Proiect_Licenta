SINTEZA

Sistem automat de control acces prin detecție și analiză spectrală a unei secvențe audio

1. Cerințele temei:
Proiectarea unui sistem de control acces care să detecteze o secvență audio formată din trei tonuri pure în ordine prestabilită, să acționeze mecanic o barieră la validarea secvenței corecte și să respingă orice altă combinație de frecvențe sau ordine incorectă, cu semnalizare vizuală și acustică.

2. Soluții alese:
Arhitectură hibridă: Arduino Uno asigură achiziția audio preluată de mirofonul MAX9814 la fs = 1429 Hz prin ADC pe 10 biți și transmite blocuri de N = 512 eșantioane prin protocolul UART la 115200 baud. MATLAB realizează pre-procesarea semnalului (eliminare DC, filtrare spike-uri, normalizare dinamică, fereastră Hanning) și analiza FFT cu o rezoluție de 2.79 Hz/bin. Detecția secvenței 440 550 660 Hz este gestionată printr-o mașină de stări finite cu CONFIRM_NEEDED = 2 și SEQ_TIMEOUT = 6s. Acționarea mecanică este realizată de servomotorul MG995 prin PWM manual, iar semnalizarea prin LED verde/roșu, buzzer activ și senzor ultrasonic HC-SR04.

3. Rezultate obținute:
Sistemul a fost validat end-to-end, demonstrând funcționalitate corectă pe întregul lanț, de la achiziția semnalului audio până la acționarea fizică a barierei, în condiții reale de testare.

4. Testări și verificări:
Au fost efectuate X teste structurate pe Y scenarii: secvență corectă ( rulări), frecvență greșită, ordine greșită, timeout, respingere activă, funcționare HC-SR04, zgomot ambiental. Testarea s-a realizat cu o aplicație de tone generator pe dispozitiv mobil la distanță de 20-30 cm față de microfon, în mediu indoor.

5. Contribuții personale:
Proiectarea și implementarea integrală a arhitecturii hardware și software, inclusiv: protocolul de comunicație bloc binar, pipeline-ul de procesare DSP, algoritmul FSM de detecție a secvenței, mecanismul PWM manual pentru servo, logica de proximitate cu HC-SR04 și interfața grafică MATLAB cu trei subploturi în timp real.

6. Surse de documentare:
Lucrări academice privind FFT, ferestre spectrale și sisteme de control acces; J. G. Proakis & D. K. Manolakis – Digital Signal Processing; A. V. Oppenheim & R. W. Schafer – Discrete-Time Signal Processing; cursurile de Semnale și Sisteme și Sisteme cu Microprocesoare din cadrul programului de studiu; documentație tehnică Arduino Uno, MAX9814, MG995, HC-SR04.
