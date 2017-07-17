classdef QN < handle
    %QN Class for approximating the Q function
    %   A neural network that can be used to approximate a Q function used
    %   in Q-learning. The network has one hidden layer, takes an input
    %   vector with length given in the constructor, and outputs one Q
    %   value.
    
    properties
        N_input % Length of input vector
        N_hidden % Number of hidden untits
        W_hidden % Weights of the hidden layer
        W_out % Weight of the output layer (a row vector, as we have only one scalar output)
        learning_rate
        regularization_factor
        discount_factor
        experience_memory
        N_exps = 0 % Number of experiences in the memory
        new_exp_place = 1 % Index to use when the network gets a new experience
        batch_size % Size of the mini-batch used for learning
        N_actions % Number of possible different actions the agent can take
        action_function % A function taking an integer between 1 and N_actions, returning the corresponding action vector
        normalization_function
    end
    
    methods
        
        function this = QN(Len_state, Len_action, N_hidden, N_actions, ...
                batch_size, learning_rate, regularization_factor, discount_factor, ...
                action_function, normalization_function, memory_size)
            %QN Creates a new Q-network
            %   N_input = the length of the networks input network
            %   N_hidden = the number of nodes in the hidden layer
            %   N_actions = the number of possible actions in the action
            %               space
            %   batch_size = the number of experience examples the
            %                network should use in one training epoch 
            %   action_function = a function mapping 1:N_actions to the
            %                     possible action vectors
            
            len_input = Len_state+Len_action;
            this.N_input = len_input;
            this.N_hidden = N_hidden;
            this.N_actions = N_actions;
            this.batch_size = batch_size;
            this.learning_rate = learning_rate;
            this.regularization_factor = regularization_factor;
            this.discount_factor = discount_factor;
            this.action_function = action_function;
            this.normalization_function = normalization_function;
            
            % Xavier initialization of weights
            sigma = 1/(len_input+1);
            this.W_hidden = rand(N_hidden, len_input+1) .* (2*sigma) - sigma; 
            sigma = 1/(N_hidden+1);
            this.W_out = rand(1, N_hidden+1) .* (2*sigma) - sigma; 
            %this.W_hidden = normrnd(0, 1/(len_input+1), [N_hidden len_input+1]);
            %this.W_out = normrnd(0, 1/(N_hidden+1), [1 N_hidden+1]);
            % One row in exp.mem.:[state action new_state reward]
            this.experience_memory = zeros(memory_size, Len_state+Len_action+Len_state+1);
        end
        
        function Q = predict(this, inp)
            inp = inp(:); % making sure it's a column vector
            inp = [1; inp]; % adding 1 to the fron for bias term
            A_hidden = [1; sigmoid(this.W_hidden * inp)]; % adding 1 to the fron for bias term
            Q = this.W_out * A_hidden;
        end
        
        function experience(this, state, action, next_state, reward)
            %EXPERIENCE Adds an experience into the network's memory
            %           If the number of experiences in the network's
            %           memory exceeds the batch_size given in the
            %           constructor, it automatically applies mini-batch
            %           training with random experiences from the memory.
            %           state = the current state of the agent as  row vector
            %           action = the action taken as a row vector
            %           reward = the reward that agent gets as a result of
            %                    the action
            
            inp = [state action];
            if this.N_exps < size(this.experience_memory, 1)
                this.N_exps = this.N_exps + 1;
            end
            this.experience_memory(this.new_exp_place, :) = ...
                [inp next_state reward];
            this.new_exp_place = this.new_exp_place + 1;
            if this.new_exp_place > size(this.experience_memory, 1)
                this.new_exp_place = 1;
            end
            
            if(this.N_exps > this.batch_size)
                experience_set = ...
                    this.experience_memory(randi(this.N_exps, [1 this.batch_size]), :);
                this.train(experience_set);
            end
        end
        
        function train(this, experience_set)
            n = size(experience_set, 1);
            h = zeros(n, 1);
            y = experience_set(:, end); % y = r
            [shape] = size(this.W_hidden);
            G_hidden = zeros(shape);
            G_out = zeros(numel(this.W_out), 1);
            for i = 1:n
                inp = this.normalization_function(experience_set(i, 1:this.N_input));
                h(i) = this.predict(inp);
                next_state = experience_set(i, this.N_input+1:end-1);
                q_next = zeros(this.N_actions, 1); % Q values in the next state
                for a = 1:this.N_actions
                    action = this.action_function(a);
                    qqriq = this.predict(this.normalization_function([next_state action]));
                    q_next(a) = qqriq;
                end
                % y = Q(s, a) = r + gamma * max(Q(s', a') a' szerint) 
                y(i) = y(i) + this.discount_factor * max(q_next);
                
                % calculate gradients
                x = [1; inp'];
                A_hidden = [1; sigmoid(this.W_hidden * x)];
                G_out = G_out + 1/n * (h(i) - y(i)) * A_hidden; 
                G_out(2:end) = ...
                    G_out(2:end) + this.regularization_factor / n * this.W_out(2:end)';
                A_hidden = A_hidden(2:end); % Removing bias term, not needed for G_hidden
                for k = 1:size(this.W_hidden, 2)
                    G_hidden(:, k) = G_hidden(:,k) + ...
                        1/n * (h(i)-y(i)) * this.W_out(2:end)' .* (A_hidden .* (1-A_hidden)) * x(k);
                end
                G_hidden(:, 1:end) = G_hidden(:, 1:end) + this.regularization_factor / n * this.W_hidden(:, 1:end);
            end
            %J = 1/n * (h - y)'*(h - y) + ...
            %    this.regularization_factor / (2*n) * (W'*W);
            prevW_hidden = this.W_hidden;
            this.W_hidden = this.W_hidden - this.learning_rate * G_hidden;
            this.W_out = this.W_out - this.learning_rate * G_out';
        end
    end
    
end

function s = sigmoid(x)
    s = 1 ./ (1+exp(-x));
end
