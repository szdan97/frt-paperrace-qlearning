env = PaperRaceEnv('PALYA3.bmp', 99, 'GG1.bmp', [ 
            350, 60,350,100;...
            360, 60,360,100;...
            539,116,517,137;...
            348,354,348,326;...
             35,200, 70,200;...
            250, 60,250,100]);
N_hidden = 100;
N_actions = 9;
batch_size = 20;
learning_rate = 0.1;
regularization_factor = 0.1;
discount_factor = 0.9;
explore = 0.9; % Elején nagy a felfedezés valószínûsége, ekkor még nem sokat tud a tereprõl, 
               % késõbb csökkentjük
explore_reduction = 0.00001;
memory_size = 2000;
state_length = 4;
action_length = 2;
qn = QN(state_length, action_length, N_hidden, N_actions, ...
        batch_size, learning_rate, regularization_factor, discount_factor, ...
        @env.GGAction, @env.normalize_data, memory_size);

delay = 0;  
N_eps = 100000; % Episodes of learning
ep = 0;
vege = false;
rew_sum = 0;
v_init = [0 1];
while ep < N_eps
    clc; ep
    rew_sum
    pos = env.KezdoPoz;
    v = v_init; % Initial velocity
    rajz = true;
    rew_sum = 0;
    if(rajz)
        clf;
        env.drawTrack();
    end
    
    while ~vege
        % Choosing action to take
        
%         %Softmax decision
%         q = zeros(N_actions, 1);
%         for a = 1:N_actions
%             action = env.GGAction(a);
%             qqriq = qn.predict(env.normalize_data([pos v action]));
%             q(a) = qqriq;
%         end
%         sm = softmax(q);
%         upper = cumsum(sm);
%         lower = [0; upper(1:end-1)];
%         a = rand;
%         action = find(a>=lower & a<upper);
%         szin = [sm(action) 1-sm(action) 1];
        
        %e-greedy decision
        if rand < explore
            action = ceil(rand * N_actions);
            szin = 'y';
        else
            szin = 'r';
            q = zeros(N_actions, 1);
            for a = 1:N_actions
                action = env.GGAction(a);
                qqriq = qn.predict(env.normalize_data([pos v action]));
                q(a) = qqriq;
            end
            [~, action] = max(q);
        end

        action = env.GGAction(action);
        [v_new, pos_new, r, vege] = env.lep(action, v, pos, rajz, szin);
        rew_sum = rew_sum + r;
        qn.experience([pos v], action, [pos_new, v_new], r);
        v = v_new; pos = pos_new;
    end
   
    explore = max(0, explore - explore_reduction);
    if(rajz)
        pause(delay);
    end
    ep = ep + 1;
    vege = false;
    env.reset;
end

%TODO: a tanultak kipróbálása: minden pozícióban a max Q-hoz tartozó akciót
%választjuk, jó esetben gyorsan végig kell érnie a pályán