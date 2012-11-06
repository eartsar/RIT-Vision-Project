% Loy and Zelinski's fast radial feature detector
%
% COPYRIGHT AND ATTRIBUTIONS LISTED BELOW
% THE ORIGINAL CODE HAS BEEN MODIFIED AS PER THE COMPUTER VISION
% COURSE AT RIT FOR ACADEMIC USE AND EXPERIMENTATION.
% 
%
% Modified by: Eitan Romanoff
% Original Author: Peter Kovesi
%
% References:
% Original:
% Loy, G.  Zelinsky, A.  Fast radial symmetry for detecting points of
% interest.  IEEE PAMI, Vol. 25, No. 8, August 2003. pp 959-973.
% 
% Modification:
% Loy, G.  Barnes, N.   Fast Shape-based Road Sign Detection for a 
% Driver Assistance System. IEEE IROS, Vol. 1, Oct 2004, pp 70-75.
%
%
%
% ORIGINAL COPYRIGHT
%
% Copyright (c) 2004-2010 Peter Kovesi
% Centre for Exploration Targeting
% The University of Western Australia
% http://www.csse.uwa.edu.au/~pk/research/matlabfns/
% 
% Permission is hereby granted, free of charge, to any person obtaining a copy
% of this software and associated documentation files (the "Software"), to deal
% in the Software without restriction, subject to the following conditions:
% 
% The above copyright notice and this permission notice shall be included in 
% all copies or substantial portions of the Software.
%
% The Software is provided "as is", without warranty of any kind.

% November 2004  - original version
% July     2005  - Bug corrected: magitude and orientation matrices were
%                  not zeroed for each radius value used (Thanks to Ben
%                  Jackson) 
% December 2009  - Gradient threshold added + minor code cleanup
% July     2010  - Gradients computed via Farid and Simoncelli's 5 tap
%                  derivative filters
% November 2012  - Modified to work as per the second reference (Eitan
%                  Romanoff)

function S = find_with_frst(im, radii, alpha, numsides)
    [rows,cols]=size(im);
    
    % Apply sobel filters to get the gradients
    gx = [-1 0 1
          -2 0 2
          -1 0 1];
    gy = gx';
    
    imgx = filter2(gx,im);
    imgy = filter2(gy,im);
    mag = sqrt(imgx.^2 + imgy.^2)+eps; % (+eps to avoid division by 0)
    
    % Add the treshhold to the magnitude
    thresh = 0.05 * max(mag(:));
    mag( mag < thresh ) = eps;
    
    % Normalise gradient values so that [imgx imgy] form unit 
    % direction vectors.
    imgx = imgx./mag;   
    imgy = imgy./mag;
    
    % Get the intersection unit vectors
    % Intersection = -x/y
    ix = -1 .* imgy;
    iy = imgx;
    
    % Pre-allocate the symmetry matrix
    S = zeros(rows,cols);
    
    % x and y are matrices corresponding to points
    [x,y] = meshgrid(1:cols, 1:rows);
    
    for n = radii
    
    % Magnitude projection image
	M = zeros(rows,cols);
    % Orientation projection image
	O = zeros(rows,cols);
    
    % get the width of the vote line
    w = round(n * tan(pi / numsides));
    % special case for circles
    if numsides == 0
        w = 0;
    end

        % Coordinates of affected pixels
        % This is the center of the vote lines
        posx = x + round(n*imgx);
        posy = y + round(n*imgy);
        
        % Removes points that go out of bounds
        posx( find(posx<1) )    = 1;
        posx( find(posx>cols) ) = cols;
        posy( find(posy<1) )    = 1;
        posy( find(posy>rows) ) = rows;
        
        % Form the orientation and magnitude projection matrices
        for r = 1:rows
            for c = 1:cols
                % Ignore if magnitude is zero
                if ~(mag(r, c) == eps)
                    pos_cx = posx(r,c);
                    pos_cy = posy(r,c);
                    
                    % if it's a circle, just vote at the center
                    if w == 0
                        O(posy(r,c),posx(r,c)) = O(posy(r,c),posx(r,c)) + 1;
                        M(posy(r,c),posx(r,c)) = M(posy(r,c),posx(r,c)) + mag(r,c);
                        continue
                    end
                    
                    % otherwise, walk to the "right" from center
                    for step = 0:(2*w)
                        ptx = round(pos_cx + (ix(r,c) * step));
                        pty = round(pos_cy + (iy(r,c) * step));
                        
                        % If the point is within image bounds, vote
                        if (ptx > cols) || (ptx < 1) || (pty > rows) || (pty < 1)
                            break
                        elseif step <= w
                            O(pty, ptx) = O(pty, ptx) + 1;
                            M(pty, ptx) = M(pty, ptx) + mag(r,c);
                        elseif step <= 2*w
                            O(pty, ptx) = O(pty, ptx) - 1;
                            M(pty, ptx) = M(pty, ptx) - mag(r,c);
                        end
                    end
                    
                    % walk to the "left" from center
                    for step = 1:(2*w)
                        ptx = round(pos_cx - (ix(r,c) * step));
                        pty = round(pos_cy - (iy(r,c) * step));
                        
                        % If the point is within image bounds, vote
                        if (ptx > cols) || (ptx < 1) || (pty > rows) || (pty < 1)
                            break
                        elseif step <= w
                            O(pty, ptx) = O(pty, ptx) + 1;
                        elseif step <= 2*w
                            O(pty, ptx) = O(pty, ptx) - 1;
                        end
                    end
                end
            end
        end
        
        % Clamp Orientation projection matrix values to a maximum of 
        % +/-kappa,  but first set the normalization parameter kappa to the
        % values suggested by Loy and Zelinski
        if n == 1, kappa = 8; else, kappa = 9.9; end
        
        O(find(O >  kappa)) =  kappa;  
        O(find(O < -kappa)) = -kappa;  
        
        % Unsmoothed symmetry measure at this radius value
        F = M./kappa .* (abs(O)/kappa).^alpha;
        
        % Generate a Gaussian of size proportional to n to smooth and spread 
        % the symmetry measure.  The Gaussian is also scaled in magnitude
        % by n so that large scales do not lose their relative weighting.
        A = fspecial('gaussian',[n n], 0.25*n) * n;  
        
        S = S + filter2(A,F);
        
    end  % for each radius
    
S = S/length(radii);  % Average 
end