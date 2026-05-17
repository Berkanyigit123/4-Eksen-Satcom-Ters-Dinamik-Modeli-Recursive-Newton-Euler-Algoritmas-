function satcom_4axis_inverse_dynamics_build()
    % =========================================================================
    % AÇIKLAMA: SAF AZİMUT ODAKLI TURRET RNE TERS DİNAMİK MODELİ
    % DÜZELTME: Tüm yapay çarpanlar, abartılı sürtünmeler ve hayali katsayılar 
    % KESİNLİKLE SİLİNMİŞTİR. Model %100 kullanıcının orijinal CAD verilerine 
    % ve saf Uzaysal Operatör Cebri (Tez) matematiğine geri döndürülmüştür.
    % =========================================================================
    
    warning('off', 'Simulink:Engine:MdlFileShadowing');
    warning('off', 'Simulink:Engine:MdlNameShadowing');
    warning('off', 'MATLAB:shadowedElements');
    
    model = "satcom_4axis_inverse_dinamik";
    
    % Geçmiş ToWorkspace verilerini temizle
    evalin('base', 'clear sim_raw_tau sim_raw_time;');
    
    t_dummy = [0; 1]; z_dummy = [0; 0];
    assignin('base', 'in_qdot_az', timeseries(z_dummy, t_dummy));
    assignin('base', 'in_qddot_az', timeseries(z_dummy, t_dummy));
    assignin('base', 'in_qdot_el', timeseries(z_dummy, t_dummy));
    assignin('base', 'in_qddot_el', timeseries(z_dummy, t_dummy));
    assignin('base', 'in_zero', timeseries(z_dummy, t_dummy));
    
    if bdIsLoaded(model), close_system(model,0); end
    if exist(model+".slx","file")==2, try, delete(model+".slx"); catch, end, end
    new_system(model); open_system(model);
    
    % =========================================================================
    % KULLANICI ARAYÜZÜ (UI) BLOKLARI
    % =========================================================================
    
    btn1 = model+"/1_TIKLA_VERI_YUKLE";
    add_block("simulink/Ports & Subsystems/Subsystem", btn1, "Position", [50, 20, 300, 80]);
    set_param(btn1, "Mask", "on", "MaskDisplay", "disp('1. ÇİFT TIKLA:\nTest Verisini Yükle (CSV/MAT)');");
    
    cb1 = [ ...
        'try, ' ...
            'evalin(''base'', ''clear sim_raw_tau sim_raw_time;''); ' ... 
            '[f,p]=uigetfile({''*.mat;*.csv;*.xlsx''}); ' ...
            'if ischar(f), ' ...
                'if ~isempty(strfind(lower(f), ''.mat'')), ' ...
                    'mat_veri = load(fullfile(p,f)); ' ...
                    'v = double(mat_veri.Motor_hizi); v=v(:); ' ...
                    'a = double(mat_veri.Motor_ivmesi); a=a(:); ' ...
                    'tau_real = double(mat_veri.Motor_torku); tau_real=tau_real(:); ' ...
                    'dt_mean = 0.005; ' ... 
                    't = (0:(length(v)-1))'' * dt_mean; t=t(:); ' ...
                'else, ' ...
                    'ham_veri = importdata(fullfile(p,f)); ' ...
                    'if isstruct(ham_veri), mat = ham_veri.data; else, mat = ham_veri; end, ' ...
                    't = double(mat(:,2)); t=t(:); ' ...
                    'v = double(mat(:,5)); v=v(:); ' ...
                    'a = double(mat(:,7)); a=a(:); ' ...
                    'akim = double(mat(:,9)); akim=akim(:); ' ...
                    'tau_real = akim * 1.41; tau_real=tau_real(:); ' ...
                    'dt_array = diff(t); dt_array(dt_array==0)=1e-6; dt_mean = mean(dt_array); ' ...
                'end, ' ...
                'z = zeros(size(t)); ' ...
                'if isnan(dt_mean) || isempty(dt_mean) || dt_mean==0, dt_mean=0.001; end, ' ...
                'assignin(''base'',''in_qdot_az'',timeseries(v,t)); ' ...
                'assignin(''base'',''in_qddot_az'',timeseries(a,t)); ' ...
                'assignin(''base'',''in_qdot_el'',timeseries(z,t)); ' ...
                'assignin(''base'',''in_qddot_el'',timeseries(z,t)); ' ...
                'assignin(''base'',''in_zero'',timeseries(z,t)); ' ...
                'assignin(''base'',''csv_zaman'',t); ' ...
                'assignin(''base'',''csv_tork'',tau_real); ' ...
                'set_param(bdroot,''SolverType'',''Fixed-step''); ' ...
                'set_param(bdroot,''Solver'',''FixedStepDiscrete''); ' ...
                'set_param(bdroot,''FixedStep'',num2str(dt_mean)); ' ...
                'set_param(bdroot,''LoadExternalInput'',''on''); ' ...
                'set_param(bdroot,''ExternalInput'',''in_qdot_az, in_qddot_az, in_qdot_el, in_qddot_el, in_zero, in_zero, in_zero, in_zero''); ' ...
                'set_param(bdroot,''StopTime'',num2str(t(end))); ' ...
                'msgbox(sprintf(''%s başarıyla yüklendi!\\nŞimdi 2. Butona basarak saf modeli koşturabilirsiniz.'', f), ''BAŞARILI''); ' ...
            'end, ' ...
        'catch ME, ' ...
            'errordlg(sprintf(''HATA:\\n%s'', ME.message), ''Sistem Hatası''); ' ...
        'end' ...
    ];
    set_param(btn1, "OpenFcn", cb1);
    
    btn2 = model+"/2_TIKLA_GRAFIK_CIZDIR";
    add_block("simulink/Ports & Subsystems/Subsystem", btn2, "Position", [350, 20, 600, 80]);
    set_param(btn2, "Mask", "on", "MaskDisplay", "disp('2. ÇİFT TIKLA:\nSimülasyonu Çalıştır ve Çiz');");
    
    cb2 = ['try, ', ...
               'mdl = get_param(bdroot, ''Name''); ', ...
               'disp(''Simülasyon koşturuluyor, lütfen bekleyin...''); ', ...
               'simOut = sim(mdl); ', ... 
               'assignin(''base'', ''out'', simOut); ', ...
               'tau_raw_ts = simOut.sim_raw_tau; ', ... 
               'tau_raw = double(tau_raw_ts.Data(:)); ', ...
               't_sim = double(tau_raw_ts.Time(:)); ', ...
               'if isempty(tau_raw), error(''Simülasyon verisi bulunamadı!''); end, ', ...
               ...
               '[t_u, idx] = unique(t_sim); tau_u = tau_raw(idx); ', ...
               'zaman = evalin(''base'', ''csv_zaman''); zaman = zaman(:); ', ...
               'tau_real = evalin(''base'', ''csv_tork''); tau_real = tau_real(:); ', ...
               ...
               'tau_model = interp1(t_u, tau_u, zaman, ''linear'', ''extrap''); tau_model = tau_model(:); ', ...
               'tau_fark = tau_model - tau_real; ', ... 
               'figure(''Name'', ''Turret Saf Fiziksel Doğrulama (Çarpansız)'', ''NumberTitle'', ''off'', ''Position'', [100, 100, 1000, 700]); ', ...
               'subplot(2,2,1); ', ...
               'plot(zaman, tau_model, ''b'', ''LineWidth'', 1.5); ', ...
               'title(''1) Model Torku (Orijinal CAD Verileri)''); xlabel(''Zaman (s)''); ylabel(''Tork (Nm)''); grid on; ', ...
               'subplot(2,2,2); ', ...
               'plot(zaman, tau_real, ''r'', ''LineWidth'', 1.5); ', ...
               'title(''2) Gerçek Sürücü Torku''); xlabel(''Zaman (s)''); ylabel(''Tork (Nm)''); grid on; ', ...
               'subplot(2,2,3); ', ...
               'plot(zaman, tau_model, ''b'', ''LineWidth'', 1.5); hold on; ', ...
               'plot(zaman, tau_real, ''r--'', ''LineWidth'', 1.5); ', ...
               'title(''3) Karşılaştırma''); xlabel(''Zaman (s)''); ylabel(''Tork (Nm)''); ', ...
               'legend(''Saf RNE Modeli'', ''Sürücü Gerçek Torku''); grid on; ', ...
               'subplot(2,2,4); ', ...
               'plot(zaman, tau_fark, ''k'', ''LineWidth'', 1.2); ', ...
               'title(''4) Fark (Model - Gerçek)''); xlabel(''Zaman (s)''); ylabel(''Hata (Nm)''); grid on; ', ...
           'catch ME, ', ...
               'errordlg(sprintf(''GRAFİK ÇİZİLEMEDİ VEYA SİMÜLASYON HATASI:\\n\\n%s'', ME.message), ''Sistem Hatası''); ', ...
           'end'];
    set_param(btn2, "OpenFcn", cb2);
    
    % =========================================================================
    % ANA EKRAN DÜZENİ VE ALT SİSTEM BAĞLANTILARI
    % =========================================================================
    x_start = 50; y_start = 140; dy_port = 40;  
    
    inNames = {"qdot_az","qddot_az", "qdot_el","qddot_el", "qdot_cross","qddot_cross", "qdot_pol","qddot_pol"};
    for i=1:numel(inNames)
        y_pos = y_start + dy_port*(i-1);
        add_block("simulink/Ports & Subsystems/In1", model+"/"+inNames{i}, "Position", [x_start, y_pos, x_start+30, y_pos+15]);
    end
    
    sys_frames   = model+"/1_Uzaysal_Tanimlamalar_Frames";
    sys_outboard = model+"/2_Ileri_Kinematik_Outboard";
    sys_inboard  = model+"/3_Geriye_Dinamik_Inboard";
    sys_torques  = model+"/4_Eklem_Torklari_Tau";
    
    w_sys = 220; h_sys = 300; gap = 100;
    x1 = x_start + 120; x2 = x1 + w_sys + gap; x3 = x2 + w_sys + gap; x4 = x3 + w_sys + gap;
    
    add_block("simulink/Ports & Subsystems/Subsystem", sys_frames,   "Position", [x1, y_start, x1+w_sys, y_start+h_sys]);
    add_block("simulink/Ports & Subsystems/Subsystem", sys_outboard, "Position", [x2, y_start, x2+w_sys, y_start+h_sys]);
    add_block("simulink/Ports & Subsystems/Subsystem", sys_inboard,  "Position", [x3, y_start, x3+w_sys, y_start+h_sys]);
    add_block("simulink/Ports & Subsystems/Subsystem", sys_torques,  "Position", [x4, y_start, x4+w_sys, y_start+h_sys]);
    
    outNames = {"tau_az","tau_el","tau_cross","tau_pol"};
    x_out = x4 + w_sys + 100;
    for i=1:numel(outNames)
        y_pos = y_start + 60*(i-1) + 40; 
        add_block("simulink/Ports & Subsystems/Out1", model+"/"+outNames{i}, "Position", [x_out, y_pos, x_out+30, y_pos+15]);
    end
    
    rebuild_FramesAndAxes(sys_frames);
    rebuild_OutboardKinematics(sys_outboard);
    rebuild_InboardForces(sys_inboard);
    rebuild_JointTorques(sys_torques);
    wire_top_level(model, inNames, outNames);
    
    try, a = Simulink.Annotation(model, "4-Eksen Turret Modeli (Yapay Çarpanlardan Arındırılmış Saf CAD)");
    a.Position = [700 20 1200 80]; a.FontSize = 14; a.FontWeight = 'bold'; catch, end
        
    set_param(model, "ZoomFactor", "FitSystem");
    try, Simulink.BlockDiagram.arrangeSystem(model); catch, end
    set_param(model, "SimulationCommand", "update");
    save_system(model); open_system(model);
    disp("SİSTEM HAZIR: Tüm yapay çarpanlar silindi. Saf Orijinal CAD modeline dönüldü.");
end

function rebuild_FramesAndAxes(path)
    open_system(path); zap(path);
    add_block("simulink/Ports & Subsystems/Out1", path+"/H_bus",   "Position", [600, 80, 630, 95]);
    add_block("simulink/Ports & Subsystems/Out1", path+"/Phi_bus", "Position", [600, 240, 630, 255]);
    add_block("simulink/Ports & Subsystems/Out1", path+"/M_bus",   "Position", [600, 400, 630, 415]);
    
    hvals = { [0;0;1], [0;1;0], [1;0;0], [0;0;1] }; zero3 = [0;0;0];
    add_block("simulink/Signal Routing/Bus Creator", path+"/BusH", "Inputs","4", "Position", [400, 50, 410, 150]);
    set_param(path+"/BusH","NonVirtualBus","off");
    
    for k=1:4
        y_base = 50 + 40*(k-1);
        add_block("simulink/Sources/Constant", path+"/h"+k, "Value",mat2str(hvals{k}), "Position", [50, y_base-15, 120, y_base]);
        add_block("simulink/Sources/Constant", path+"/z3_"+k, "Value",mat2str(zero3), "Position", [50, y_base+5, 120, y_base+20]);
        add_block("simulink/Signal Routing/Mux", path+"/muxH"+k, "Inputs","2", "Position", [180, y_base-10, 190, y_base+15]);
        al(path, "h"+k+"/1",   "muxH"+k+"/1");
        al(path, "z3_"+k+"/1", "muxH"+k+"/2");
        al_name(path, "muxH"+k+"/1", "BusH/"+k, "muxH"+num2str(k));
    end
    al(path, "BusH/1","H_bus/1");
    
    get_phi = @(r) [eye(3), zeros(3); [0 r(3) -r(2); -r(3) 0 r(1); r(2) -r(1) 0], eye(3)];
    r1 = [0; 0; 0]; r2 = [0; 0; 0.180]; r3 = [0; 0; 0.090]; r4 = [0; 0; 0.060]; 
    Phi_vals = {get_phi(r1), get_phi(r2), get_phi(r3), get_phi(r4)};
    
    add_block("simulink/Signal Routing/Bus Creator", path+"/BusPhi", "Inputs","4", "Position", [400, 200, 410, 300]);
    set_param(path+"/BusPhi","NonVirtualBus","off");
    
    for k=1:4
        y_base = 200 + 25*(k-1);
        add_block("simulink/Sources/Constant", path+"/Phi"+k, "Value",mat2str(Phi_vals{k}), "Position", [180, y_base, 260, y_base+15]);
        al_name(path, "Phi"+k+"/1","BusPhi/"+k, "Phi"+num2str(k));
    end
    al(path, "BusPhi/1","Phi_bus/1");
    
    skew_c = @(c) [0 -c(3) c(2); c(3) 0 -c(1); -c(2) c(1) 0];
    get_M_iso = @(m, I, c) [diag([I,I,I]) - m*skew_c(c)*skew_c(c), m*skew_c(c); -m*skew_c(c), m*eye(3)];
    get_M_diag = @(m, I_vec, c) [diag(I_vec) - m*skew_c(c)*skew_c(c), m*skew_c(c); -m*skew_c(c), m*eye(3)];
    
    % KULLANICININ ORİJİNAL TERTEMİZ CAD KÜTLELERİ
    m1 = 16.797; I1 = 0.320977; c1 = [0; 0; 0.014069]; M1_val = get_M_iso(m1, I1, c1);
    m2 = 6.0694; I2_vec = [0.2765382961; 0.2591821156; 0.0952572160]; c2 = [0.0042710; -0.0039766; 0]; M2_val = get_M_diag(m2, I2_vec, c2);
    m3 = 4.334;  I3 = 0.053317; c3 = [0; 0; 0.004370]; M3_val = get_M_iso(m3, I3, c3);
    m4 = 2.077;  I4 = 0.004632; c4 = [0; 0; 0.001946]; M4_val = get_M_iso(m4, I4, c4);
    
    M_vals = {M1_val, M2_val, M3_val, M4_val};
    
    add_block("simulink/Signal Routing/Bus Creator", path+"/BusM", "Inputs","4", "Position", [400, 350, 410, 450]);
    set_param(path+"/BusM","NonVirtualBus","off");
    for k=1:4
        y_base = 350 + 25*(k-1);
        add_block("simulink/Sources/Constant", path+"/M"+k, "Value",mat2str(M_vals{k}), "Position", [180, y_base, 260, y_base+15]);
        al_name(path, "M"+k+"/1","BusM/"+k, "M"+num2str(k));
    end
    al(path, "BusM/1","M_bus/1");
end

function rebuild_OutboardKinematics(path)
    open_system(path); zap(path);
    add_block("simulink/Ports & Subsystems/In1", path+"/H_bus",   "Position", [20, 80, 50, 95]);
    add_block("simulink/Ports & Subsystems/In1", path+"/Phi_bus", "Position", [20, 160, 50, 175]);
    for k=1:4
        y_base = 240 + 40*(k-1);
        add_block("simulink/Ports & Subsystems/In1", path+"/qdot"+k,  "Position", [20, y_base, 50, y_base+15]);
        add_block("simulink/Ports & Subsystems/In1", path+"/qddot"+k, "Position", [20, y_base+20, 50, y_base+35]);
    end
    
    add_block("simulink/Signal Routing/Bus Selector", path+"/SelH",   "Position", [100, 60, 110, 120]);
    add_block("simulink/Signal Routing/Bus Selector", path+"/SelPhi", "Position", [100, 140, 110, 200]);
    al(path,"H_bus/1","SelH/1"); 
    al(path,"Phi_bus/1","SelPhi/1");
    set_param(path+"/SelH","OutputSignals","muxH1,muxH2,muxH3,muxH4"); 
    set_param(path+"/SelPhi","OutputSignals","Phi1,Phi2,Phi3,Phi4");
    
    add_block("simulink/Signal Routing/Mux", path+"/MuxQdot",  "Inputs","4", "Position", [150, 240, 160, 310]);
    add_block("simulink/Signal Routing/Mux", path+"/MuxQddot", "Inputs","4", "Position", [150, 320, 160, 390]);
    for k=1:4
        al(path,"qdot"+k+"/1","MuxQdot/"+num2str(k)); 
        al(path,"qddot"+k+"/1","MuxQddot/"+num2str(k));
    end
    
    add_block("simulink/Signal Routing/Mux", path+"/MuxAll", "Inputs","10", "Position", [350, 60, 360, 400]);
    for k=1:4
        al(path,"SelH/"+num2str(k), "MuxAll/"+num2str(k));
        y_res = 120 + 40*(k-1);
        add_block("simulink/Math Operations/Reshape", path+"/ReshapePhi"+k, "OutputDimensionality", "1-D array", "Position", [200, y_res, 240, y_res+20]);
        al(path,"SelPhi/"+num2str(k), "ReshapePhi"+k+"/1"); 
        al(path,"ReshapePhi"+k+"/1", "MuxAll/"+num2str(4+k));
    end
    al(path,"MuxQdot/1", "MuxAll/9"); 
    al(path,"MuxQddot/1","MuxAll/10");
    
    add_block("simulink/User-Defined Functions/MATLAB Function", path+"/Outboard_Hesap", "Position", [450, 180, 650, 280]);
    sf_set_script_robust(path+"/Outboard_Hesap", outboard_script()); 
    al(path,"MuxAll/1", "Outboard_Hesap/1");
    
    add_block("simulink/Signal Routing/Demux", path+"/DemuxOut", "Outputs","[6 6 6 6 6 6 6 6]", "Position", [750, 100, 760, 360]);
    al(path,"Outboard_Hesap/1", "DemuxOut/1");
    add_block("simulink/Signal Routing/Bus Creator", path+"/BusV",    "Inputs","4", "Position", [900,  100, 910, 200]);
    add_block("simulink/Signal Routing/Bus Creator", path+"/BusVdot", "Inputs","4", "Position", [900, 250, 910, 350]);
    set_param(path+"/BusV","NonVirtualBus","off"); 
    set_param(path+"/BusVdot","NonVirtualBus","off");
    for k=1:4
        al_name(path,"DemuxOut/"+num2str(k), "BusV/"+num2str(k), "V"+num2str(k)); 
        al_name(path,"DemuxOut/"+num2str(4+k), "BusVdot/"+num2str(k), "Vdot"+num2str(k)); 
    end
    add_block("simulink/Ports & Subsystems/Out1", path+"/V_bus", "Position", [1000, 140, 1030, 155]);
    add_block("simulink/Ports & Subsystems/Out1", path+"/Vdot_bus", "Position", [1000, 290, 1030, 305]);
    al(path,"BusV/1","V_bus/1"); 
    al(path,"BusVdot/1","Vdot_bus/1");
end

function rebuild_InboardForces(path)
    open_system(path); zap(path);
    add_block("simulink/Ports & Subsystems/In1", path+"/Phi_bus",  "Position", [20, 60, 50, 75]);
    add_block("simulink/Ports & Subsystems/In1", path+"/M_bus",    "Position", [20, 180, 50, 195]);
    add_block("simulink/Ports & Subsystems/In1", path+"/V_bus",    "Position", [20, 300, 50, 315]);
    add_block("simulink/Ports & Subsystems/In1", path+"/Vdot_bus", "Position", [20, 420, 50, 435]);
    
    add_block("simulink/Signal Routing/Bus Selector", path+"/SelPhi",  "Position", [100, 40, 110, 100]);
    add_block("simulink/Signal Routing/Bus Selector", path+"/SelM",    "Position", [100, 160, 110, 220]);
    add_block("simulink/Signal Routing/Bus Selector", path+"/SelV",    "Position", [100, 280, 110, 340]);
    add_block("simulink/Signal Routing/Bus Selector", path+"/SelVdot", "Position", [100, 400, 110, 460]);
    
    al(path,"Phi_bus/1","SelPhi/1"); 
    al(path,"M_bus/1","SelM/1");
    al(path,"V_bus/1","SelV/1"); 
    al(path,"Vdot_bus/1","SelVdot/1");
    set_param(path+"/SelPhi","OutputSignals","Phi1,Phi2,Phi3,Phi4"); 
    set_param(path+"/SelM","OutputSignals","M1,M2,M3,M4");
    set_param(path+"/SelV","OutputSignals","V1,V2,V3,V4"); 
    set_param(path+"/SelVdot","OutputSignals","Vdot1,Vdot2,Vdot3,Vdot4");
    
    add_block("simulink/Signal Routing/Mux", path+"/MuxAll", "Inputs","16", "Position", [380, 40, 390, 460]);
    for k=1:4
        y_phi = 40 + 30*(k-1); 
        add_block("simulink/Math Operations/Reshape", path+"/ReshapePhi"+k, "OutputDimensionality", "1-D array", "Position", [220, y_phi, 260, y_phi+20]);
        al(path,"SelPhi/"+num2str(k), "ReshapePhi"+k+"/1"); 
        al(path,"ReshapePhi"+k+"/1", "MuxAll/"+num2str(k));
        
        y_m = 160 + 30*(k-1); 
        add_block("simulink/Math Operations/Reshape", path+"/ReshapeM"+k, "OutputDimensionality", "1-D array", "Position", [220, y_m, 260, y_m+20]);
        al(path,"SelM/"+num2str(k), "ReshapeM"+k+"/1"); 
        al(path,"ReshapeM"+k+"/1", "MuxAll/"+num2str(4+k));
        
        al(path,"SelV/"+num2str(k), "MuxAll/"+num2str(8+k)); 
        al(path,"SelVdot/"+num2str(k), "MuxAll/"+num2str(12+k));
    end
    
    add_block("simulink/User-Defined Functions/MATLAB Function", path+"/Inboard_Hesap", "Position", [500, 200, 700, 300]);
    sf_set_script_robust(path+"/Inboard_Hesap", inboard_script()); 
    al(path,"MuxAll/1", "Inboard_Hesap/1");
    
    add_block("simulink/Signal Routing/Demux", path+"/DemuxOut", "Outputs","[6 6 6 6]", "Position", [800, 200, 810, 300]);
    al(path,"Inboard_Hesap/1", "DemuxOut/1");
    
    add_block("simulink/Signal Routing/Bus Creator", path+"/BusF", "Inputs","4", "Position", [950, 200, 960, 300]);
    set_param(path+"/BusF","NonVirtualBus","off");
    for k=1:4, al_name(path,"DemuxOut/"+num2str(k),"BusF/"+num2str(k),"F"+num2str(k)); end
    
    add_block("simulink/Ports & Subsystems/Out1", path+"/F_bus", "Position", [1050, 240, 1080, 255]);
    al(path,"BusF/1","F_bus/1");
end

function rebuild_JointTorques(path)
    open_system(path); zap(path);
    add_block("simulink/Ports & Subsystems/In1", path+"/H_bus", "Position", [20, 80, 50, 95]);
    add_block("simulink/Ports & Subsystems/In1", path+"/F_bus", "Position", [20, 200, 50, 215]);
    
    for k=1:4
        y_in = 260 + 40*(k-1);
        add_block("simulink/Ports & Subsystems/In1", path+"/qdot"+k, "Position", [20, y_in, 50, y_in+15]);
    end
    
    add_block("simulink/Signal Routing/Bus Selector", path+"/SelH", "Position", [100, 60, 110, 120]);
    add_block("simulink/Signal Routing/Bus Selector", path+"/SelF", "Position", [100, 180, 110, 240]);
    al(path,"H_bus/1","SelH/1"); 
    al(path,"F_bus/1","SelF/1");
    set_param(path+"/SelH","OutputSignals","muxH1,muxH2,muxH3,muxH4"); 
    set_param(path+"/SelF","OutputSignals","F1,F2,F3,F4");
    
    add_block("simulink/Signal Routing/Mux", path+"/MuxAll", "Inputs","12", "Position", [250, 60, 260, 420]);
    for k=1:4
        al(path,"SelH/"+num2str(k), "MuxAll/"+num2str(k)); 
        al(path,"SelF/"+num2str(k), "MuxAll/"+num2str(4+k));
        al(path,"qdot"+k+"/1", "MuxAll/"+num2str(8+k));
    end
    
    add_block("simulink/User-Defined Functions/MATLAB Function", path+"/Tork_Hesap", "Position", [350, 100, 550, 200]);
    sf_set_script_robust(path+"/Tork_Hesap", tau_script()); 
    al(path,"MuxAll/1", "Tork_Hesap/1");
    
    add_block("simulink/Signal Routing/Demux", path+"/DemuxOut", "Outputs","[1 1 1 1]", "Position", [650, 100, 660, 200]);
    al(path,"Tork_Hesap/1", "DemuxOut/1");
    
    for k=1:4
        y_out = 100 + 40*(k-1); 
        add_block("simulink/Ports & Subsystems/Out1", path+"/tau"+k, "Position", [750, y_out, 780, y_out+15]);
        al(path,"DemuxOut/"+num2str(k), "tau"+k+"/1"); 
    end
    
    add_block("simulink/Sinks/To Workspace", path+"/ToWs_TauAz", "Position", [750, 40, 850, 70]);
    set_param(path+"/ToWs_TauAz", "VariableName", "sim_raw_tau", "SaveFormat", "Timeseries");
    al(path,"DemuxOut/1", "ToWs_TauAz/1"); 
end

function wire_top_level(model, inNames, outNames)
    al(model, "1_Uzaysal_Tanimlamalar_Frames/1", "2_Ileri_Kinematik_Outboard/1");
    al(model, "1_Uzaysal_Tanimlamalar_Frames/2", "2_Ileri_Kinematik_Outboard/2");
    al(model, "1_Uzaysal_Tanimlamalar_Frames/2", "3_Geriye_Dinamik_Inboard/1");     
    al(model, "1_Uzaysal_Tanimlamalar_Frames/3", "3_Geriye_Dinamik_Inboard/2");     
    al(model, "1_Uzaysal_Tanimlamalar_Frames/1", "4_Eklem_Torklari_Tau/1");      
    for k=1:4
        al(model, inNames{2*k-1}+"/1", "2_Ileri_Kinematik_Outboard/"+num2str(2+(2*k-1)));
        al(model, inNames{2*k}  +"/1", "2_Ileri_Kinematik_Outboard/"+num2str(2+(2*k)));
    end
    al(model, "2_Ileri_Kinematik_Outboard/1", "3_Geriye_Dinamik_Inboard/3");
    al(model, "2_Ileri_Kinematik_Outboard/2", "3_Geriye_Dinamik_Inboard/4");
    al(model, "3_Geriye_Dinamik_Inboard/1", "4_Eklem_Torklari_Tau/2"); 
    
    al(model, inNames{1}+"/1", "4_Eklem_Torklari_Tau/3"); 
    al(model, inNames{3}+"/1", "4_Eklem_Torklari_Tau/4"); 
    al(model, inNames{5}+"/1", "4_Eklem_Torklari_Tau/5"); 
    al(model, inNames{7}+"/1", "4_Eklem_Torklari_Tau/6"); 
    
    for k=1:4, al(model, "4_Eklem_Torklari_Tau/"+num2str(k), outNames{k}+"/1"); end
end

function sf_set_script_robust(blockPath, scriptText)
    try, hBlock = get_param(blockPath, 'Handle'); chartId = sfprivate('block2chart', hBlock); rt = sfroot; chartObj = rt.idToHandle(chartId); chartObj.Script = scriptText; catch, end
end
function zap(sys)
    blks = find_system(sys, "SearchDepth", 1, "Type", "Block"); blks = setdiff(string(blks), string(sys));
    for b=1:numel(blks), try, delete_block(blks(b)); catch, end; end
    lns = find_system(sys, "FindAll","on", "Type","Line"); for i=1:numel(lns), try, delete_line(lns(i)); catch, end; end
end
function al(sys, src, dst), try, add_line(sys, src, dst, "autorouting","on"); catch, end; end
function al_name(sys, src, dst, sigName)
    try, parts = split(src, "/"); ph = get_param(sys + "/" + parts(1), 'PortHandles'); set_param(ph.Outport(str2double(parts(2))), 'Name', sigName); catch, end
    try, add_line(sys, src, dst, "autorouting","on"); catch, end
end

function s = outboard_script()
lines = {
'function y = fcn(u)'
'H = cell(4,1); Phi = cell(4,1); idx = 1;'
'for k=1:4, H{k} = u(idx:idx+5); idx = idx + 6; end'
'for k=1:4, Phi{k} = reshape(u(idx:idx+35), 6, 6); idx = idx + 36; end'
'qdot = u(idx:idx+3); idx = idx + 4; qddot = u(idx:idx+3);'
'Vprev = zeros(6,1); Vdotprev = [0; 0; 0; 0; 0; 9.81]; '
'V = cell(4,1); Vd = cell(4,1);'
'for k=1:4'
'  Vk  = Phi{k}*Vprev + H{k}*qdot(k);'
'  Vdk = Phi{k}*Vdotprev + H{k}*qddot(k) + crm(Vk)*(H{k}*qdot(k));'
'  V{k}=Vk; Vd{k}=Vdk; Vprev=Vk; Vdotprev=Vdk;'
'end'
'y = zeros(48,1); idx = 1;'
'for k=1:4, y(idx:idx+5) = V{k}; idx = idx + 6; end'
'for k=1:4, y(idx:idx+5) = Vd{k}; idx = idx + 6; end'
'end'
'function X = crm(V), w = V(1:3); v = V(4:6); X = [skew(w), zeros(3,3); skew(v), skew(w)]; end'
'function S = skew(a), S = [0, -a(3), a(2); a(3), 0, -a(1); -a(2), a(1), 0]; end'
};
s = sprintf('%s\n', lines{:});
end

function s = inboard_script()
lines = {
'function y = fcn(u)'
'Phi = cell(4,1); I_mat = cell(4,1); V = cell(4,1); Vd = cell(4,1); idx = 1;'
'for k=1:4, Phi{k} = reshape(u(idx:idx+35), 6, 6); idx = idx + 36; end'
'for k=1:4, I_mat{k} = reshape(u(idx:idx+35), 6, 6); idx = idx + 36; end'
'for k=1:4, V{k} = u(idx:idx+5); idx = idx + 6; end'
'for k=1:4, Vd{k} = u(idx:idx+5); idx = idx + 6; end'
'F=cell(4,1); Fchild=zeros(6,1);'
'for k=4:-1:1'
'  Fk = I_mat{k}*Vd{k} + crf(V{k})*I_mat{k}*V{k} + Fchild;'
'  F{k}=Fk;'
'  if k>1, Fchild = Phi{k}'' * Fk; end'
'end'
'y = zeros(24,1); idx = 1;'
'for k=1:4, y(idx:idx+5) = F{k}; idx = idx + 6; end'
'end'
'function X=crf(V), X=-crm(V)''; end'
'function X=crm(V), w=V(1:3); v=V(4:6); X=[skew(w) zeros(3,3); skew(v) skew(w)]; end'
'function S=skew(a), S=[0 -a(3) a(2); a(3) 0 -a(1); -a(2) a(1) 0]; end'
};
s = sprintf('%s\n', lines{:});
end

function s = tau_script()
lines = {
'function y = fcn(u)'
'H = cell(4,1); F = cell(4,1); qdot = zeros(4,1); idx = 1;'
'for k=1:4, H{k} = u(idx:idx+5); idx = idx + 6; end'
'for k=1:4, F{k} = u(idx:idx+5); idx = idx + 6; end'
'for k=1:4, qdot(k) = u(idx); idx = idx + 1; end'
'y = zeros(4,1);'
'Fc = [0.1; 0.1; 0.1; 0.1]; % Orjinal değerler'
'Fv = [0.1; 0.1; 0.1; 0.1]; % Orjinal değerler'
'for k=1:4'
'  tau_dinamik = H{k}'' * F{k}; '
'  tau_surtunme = Fc(k) * sign(qdot(k)) + Fv(k) * qdot(k);'
'  y(k) = tau_dinamik + tau_surtunme; '
'end'
'end'
};
s = sprintf('%s\n', lines{:});
end