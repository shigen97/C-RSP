function [varargout] = CRSP(A, n, k, m, b, labels)
% Common - Randomized Shortest Paths
% Inputs:
% A - multilayer affinity tensor
% n - no. of nodes
% k - no. of clusters
% m - no. of layers
% b - RSP tuning paramter
% labels - true cluster assignments of nodes
% Outputs:
% If only one, wanted distances, so return dRSP
% else, return metrics:
%   acc_arr - accuracy 
%   nmi_arr - normalized mutual information
%   final_labels - estimated labels from RSP
% Anuththari Gamage, 3/22/2018
% Modified Brian Rappaport, 7/4/2018
% Modified, AG, BR, 9/19/2018

    infFlag = 1e12;
    
    P_ref = cell(1,m);                  % Reference transition probability
    for i = 1:m
        node_degrees = sum(A{i},2);
        node_degrees(node_degrees == 0) = infFlag;
        inv_D = sparse(1:n, 1:n, 1./node_degrees);  % Inverse of Degree matrix
        P_ref{i} = inv_D*A{i};      
    end
       
    % Construct common W
    C = cellfun(@(A) 1./(A + infFlag*(A==0)),A,'un',0);           % Convert A into C
    C_joint = combine_C(C,infFlag);            % Combined cost matrix   
    P_joint = combine_P(P_ref);                % Combines probability matrix
    W = P_joint.*exp(-b*C_joint);              % Combined weights
   
    specRadius = eigs(W,1);                    % Convergence check
    if specRadius >= 1
     %   error('Will not converge')
        disp('Will not converge')
    end
    
    Z = inv(speye(n) - W);
    S = (Z*(C_joint.*W)*Z)./Z;
    C_bar = S - ones(n,1)*diag(S)';
    dRSP = (C_bar + C_bar')./2;   
    dRSP(isnan(dRSP)) = infFlag;                 % Flagging inf
    
    if nargout == 1
        varargout{1} = dRSP;
    else
        % Spectral Clustering   
        aff = 1./(eye(n) + dRSP) - eye(n);      % Affinity Matrix
        D = diag(1./sqrt(sum(aff,2)));
        L = D*aff*D;          % Normalized Laplacian
%         [V,~] = eigs(L,k+1);
%         V = V./sqrt(sum(V.^2,2));
%         V = V(:,2:end);
        [V,E] = eig(L);
        [~,I] = sort(diag(E),'descend');
        V = V(:, I(2:k+1)');                     % Changed to take from second largest ei.value onwards
        V = V./sqrt(sum(V.^2,2));


        [final_labels,acc_arr,nmi_arr] = postproc(V,k,labels);
        varargout{1} = acc_arr;
        varargout{2} = nmi_arr;
        varargout{3} = final_labels;
    end
end

function new_C = combine_C(C,infFlag)
    m = numel(C);
    threshold = infFlag/2;
    new_C = C{1}.*(C{1} < threshold);  % gets rid of inf costs
    nz_C = C{1}~=0;         % Tracks count of non-zero costs
    for layers = 2:m
        new_C = new_C + C{layers}.*(C{layers} < threshold);
        nz_C = nz_C + (C{layers}~=0);
    end
    new_C = new_C./(nz_C + (nz_C==0));
end


function new_P = combine_P(P)
    n = size(P{1},1);
    m = numel(P);
    mask = false(n,n,m);
    new_P = ones(n);
    for ii = 1:m
        mask(:,:,ii) = P{ii} ~= 0;
        new_P(mask(:,:,ii)) = new_P(mask(:,:,ii)).*P{ii}(mask(:,:,ii));
    end
    roots = sum(mask,3);
    new_P = nthroot(new_P,roots);
    new_P(isnan(new_P)) = 0;
    new_P = new_P./(sum(new_P,2));     % Make row stochastic
    new_P(isnan(new_P)) = 0;
end