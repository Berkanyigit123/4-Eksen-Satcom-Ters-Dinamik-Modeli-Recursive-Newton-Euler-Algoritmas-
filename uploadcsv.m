% =========================================================================
% T1.CSV VERİLERİNİ SİMULİNK MODELİNE BESLEME VE ÇIKTI ALMA KODU (TAMAMI)
% =========================================================================
clc; clear; close all;

%% 1. CSV Verilerini Okuma (İsim Karmaşasını Önlemek İçin Matris Olarak Okuyoruz)
disp('1. T1.csv dosyası okunuyor...');
mat_data = readmatrix('T2.csv');

% T1.csv dosyasındaki sütun indeksleri (0'dan değil 1'den başlar):
zaman    = mat_data(:, 2);  % Time
az_vel   = mat_data(:, 5);  % Azimut Hızı (qdot)
az_acc   = mat_data(:, 7);  % Azimut İvmesi (qddot)
az_ctrl  = mat_data(:, 9);  % Karşılaştırma için gerçek sistem torku

% Hepsini dikey sütun (vektör) yapmayı garanti altına alalım
zaman = zaman(:); 
az_ctrl = az_ctrl(:);

%% 2. Simulink İçin Zaman Serileri (Timeseries) Oluşturma
disp('2. Simulink için giriş verileri hazırlanıyor...');
qdot_az_ts  = timeseries(az_vel, zaman);
qddot_az_ts = timeseries(az_acc, zaman);

% Diğer 3 eksen (Elevasyon, Cross, Pol) için elimizde test verisi yok, 0 veriyoruz.
sifir_dizi = zeros(size(zaman));
sifir_ts   = timeseries(sifir_dizi, zaman);

% Simulink inportları bu değişkenleri Base Workspace'den okur
assignin('base', 'in_qdot_az', qdot_az_ts);
assignin('base', 'in_qddot_az', qddot_az_ts);
assignin('base', 'in_zero', sifir_ts);

%% 3. Modeli Ayarlama ve Simülasyonu Başlatma
model_adi = "satcom_4axis_inverse_dinamik";
disp(['3. ' char(model_adi) ' modeli simüle ediliyor... (Lütfen bekleyin)']);

% Modeli yükle (açık değilse arka planda açar)
load_system(model_adi);

% Dışarıdan veri alma ayarını aç ve giriş sırasını belirle
set_param(model_adi, 'LoadExternalInput', 'on');
giris_sirasi = 'in_qdot_az, in_qddot_az, in_zero, in_zero, in_zero, in_zero, in_zero, in_zero';
set_param(model_adi, 'ExternalInput', giris_sirasi);

% Simülasyon süresini test verisinin son saniyesi yap
son_saniye = num2str(zaman(end));
set_param(model_adi, 'StopTime', son_saniye);

% Simülasyonu Çalıştır
out = sim(model_adi);

disp('Simülasyon başarıyla tamamlandı!');

%% 4. Çıktıları Alma, Boyut Eşitleme ve Dosyaya Kaydetme (DIŞA AKTARIM)
disp('4. Çıktılar alınıyor ve hizalanıyor...');

% Modelin ürettiği Azimut torkunu (tau_az) ve modelin kendi zamanını çek
% NOT: (:) işareti kullanılarak matris boyutu düz bir sütuna zorlanır!
tau_az_raw = double(out.yout{1}.Values.Data(:)); 
t_sim      = double(out.yout{1}.Values.Time(:));

% Özel Durum: Simulink bazen aynı saniyede 2 değer (step) üretebilir. 
% Bu yüzden eşsiz (unique) zaman adımlarını alıyoruz.
[t_sim_uniq, idx_uniq] = unique(t_sim);
tau_az_uniq = tau_az_raw(idx_uniq);

% BOYUT EŞİTLEME (İnterpolasyon): Simulink verisini orijinal Excel satırlarına hizala
tau_az_model = interp1(t_sim_uniq, tau_az_uniq, zaman, 'linear', 'extrap');
tau_az_model = tau_az_model(:); % Bunu da sütun yapalım

% Artık hepsi aynı boyutta! Tabloyu oluşturabiliriz:
SonucTablosu = table(zaman, tau_az_model, az_ctrl, ...
    'VariableNames', {'Zaman_saniye', 'Model_Uretilen_Tork_Nm', 'Gercek_Sistem_Tork_Referansi'});

% ÇIKTIYI CSV OLARAK KAYDET
writetable(SonucTablosu, 'Model_Tork_Sonuclari.csv');
disp('>>> BAŞARILI: Çıktılar "Model_Tork_Sonuclari.csv" adlı dosyaya kaydedildi!');

%% 5. Çıktıları Görselleştirme
disp('5. Grafikler çizdiriliyor...');
figure('Name', 'Model Tork Çıktısı vs Gerçek Tork', 'NumberTitle', 'off');
plot(zaman, tau_az_model, 'b', 'LineWidth', 1.5); hold on;
plot(zaman, az_ctrl, 'r--', 'LineWidth', 1.2);
xlabel('Zaman (s)');
ylabel('Tork (Nm)');
title('Azimut Motoru Tork Çıktıları (Eşitlenmiş Veri)');
legend('Ters Dinamik Modelinin Çıktısı', 'T1.csv İçindeki Kontrolör Çıktısı');
grid on;