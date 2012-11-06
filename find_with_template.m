% Code was written independently from, but according
% to the strategy as defined by source 3 of the report.
%
% I'm actually jealous at how much better their solution works.
%
% Author: Eitan Romanoff

function [] = find_with_template(im_name, query)
    all_flag = strcmp(query,'all');
    stop_flag = strcmp(query,'stop') || all_flag;
    speed_flag = strcmp(query,'speed') || all_flag;
    yellow_flag = strcmp(query,'caution') || all_flag;
    green_flag = strcmp(query,'street') || all_flag;
    good_args = stop_flag || speed_flag || yellow_flag || green_flag;
    
    if ~good_args
       display('  Bad arguments.');
       display('  Usage: find_with_template(im_name, query)');
       display('  Possible queries: stop, speed, caution, street, all');
       return
    end
    

    im = imread(im_name);
    [sh sw sd] = size(im);
    if min(sh, sw) > 800
        im = im2double(imresize(imread(im_name), 0.5));
    end
    
    % STOP SIGN
    if stop_flag
        t_stop = imread('templates/stop-template.png');
        [th tw td] = size(t_stop);
        t_reduce = 20 / min(th, tw);
        t_stop = im2double(imresize(t_stop, t_reduce));
        [th tw td] = size(t_stop);
        ret_stop = get_matches(im, t_stop);

        % Find the longest dimension of the template, and find a constant 
        % for making the bounding boxes later. To make my life easier, 
        % assume symmetry.
        ss_box_offset = (max(tw, th) / 1.9);
    end
       
    % SPEED SIGNS
    if speed_flag
        t_speed = imread('templates/speed-template.png');
        [th tw td] = size(t_speed);
        t_reduce = 20 / min(th, tw);
        t_speed = im2double(imresize(t_speed, t_reduce));
        [th tw td] = size(t_speed);
        ret_speed = get_matches(im, t_speed);
        speed_top_offset = 0.9 * th;
        speed_height = speed_top_offset + (3 * th) + th;
        speed_width_offset = 0.65 * tw;        
    end

    % YELLOW SIGNS
    if yellow_flag
        t_yellow = imread('templates/yellow-template.png');
        [th tw td] = size(t_yellow);
        t_reduce = 20 / min(th, tw);
        t_yellow = im2double(imresize(t_yellow, t_reduce));
        [th tw td] = size(t_yellow);
        ret_yellow = get_matches(im, t_yellow);
        yellow_offset = 0.5 * th;
    end
    
    % STREET SIGNS
    if green_flag
        t_green = imread('templates/green-template.png');
        [th tw td] = size(t_green);
        t_reduce = 20 / min(th, tw);
        t_green = im2double(imresize(t_green, t_reduce));
        [th tw td] = size(t_green);
        ret_green = get_matches(im, t_green);
        green_height_offset = th * 0.5;
        green_width_offset = tw * 0.5
    end

    
    
    
    imshow(im);
    hold on

    if stop_flag && ~isempty(ret_stop)
        dims = [(ret_stop(:,4) - (ss_box_offset./(ret_stop(:,1)))) ...
            (ret_stop(:,3) - (ss_box_offset./(ret_stop(:,1)))) ...
            (ss_box_offset./(ret_stop(:,1))*2) ...
            (ss_box_offset./(ret_stop(:,1))*2)];
        for i = 1:size(dims)
            rectangle('position', dims(i,:), 'edgecolor', 'm', 'linewidth', 3);
        end
    end
    
    if speed_flag && ~isempty(ret_speed)
        dims = [(ret_speed(:,4) - (speed_top_offset./(ret_speed(:,1)))) ...
            (ret_speed(:,3) - (speed_width_offset./(ret_speed(:,1)))) ...
            (speed_width_offset/(ret_speed(:,1))*2) ...
            speed_height];
        for i = 1:size(dims)
            rectangle('position', dims(i,:), 'edgecolor', 'm', 'linewidth', 3);
        end
    end
    
    if yellow_flag && ~isempty(ret_yellow)
        dims = [(ret_yellow(:,4) - (yellow_offset./(ret_yellow(:,1)))) ...
            (ret_yellow(:,3) - (yellow_offset./(ret_yellow(:,1)))) ...
            (yellow_offset./(ret_yellow(:,1))*2) ...
            (yellow_offset./(ret_yellow(:,1))*2)];
        for i = 1:size(dims)
            rectangle('position', dims(i,:), 'edgecolor', 'm', 'linewidth', 3);
        end
    end
    
    if green_flag && ~isempty(ret_green)
        dims = [(ret_green(:,4) - (green_height_offset./(ret_green(:,1)))) ...
            (ret_green(:,3) - (green_width_offset./(ret_green(:,1)))) ...
            ((green_width_offset * 2)./(ret_green(:,1))*2) ...
            ((green_height_offset * 2)./(ret_green(:,1))*2)];
        for i = 1:size(dims)
            rectangle('position', dims(i,:), 'edgecolor', 'm', 'linewidth', 3);
        end
    end
end


function [ret] = get_matches(im, sign_template)

% Set up the template. My template is pretty big, so I scale it down
% to be much smaller. This saves computation time, but also allows it to
% effectively pick up signs in the distance.
%
% Also, scale down the template

% Read in the image we're going to search for stop signs in. I scale down
% to 50% of the size to reduce computation time.


% Get the sizes of the images.
[template_height template_width template_depth] = size(sign_template);
[im_height im_width im_depth] = size(im);
prune_dim = (max(im_width, im_height) / 1.9);

% We want the template to always be smaller than the image. Since the image
% will be resized, rather than the template, make sure that scaling down
% the image is done according to to the bigger ratio. This ensures that the
% image is always bigger than the template.
ratio_major = max(template_width/im_width, template_height/im_height);

% Used for the resizing in the loop. Smaller for more accuracy, bigger for
% speed.
ratio_step = 0.03;

% Store the scales with their respective correlation values and locations. 
% Use this later to find the peaks.
corr_results = [];

% Start with the image "fit to" the template, then scale it back towards
% its original size.
for i = ratio_major : ratio_step : 1
    % Resize the image
    im_resized = imresize(im, i);

    % Correlate between the three color planes in RGB space
    % An average should suffice here.
    % Buffer the non-overlap parts with zeroes to avoid affecting the max.
    % TODO: Try a different color space if it doesn't work.
    correlation = normxcorr2(sign_template(:,:,1), im_resized(:,:,1));
    correlation = correlation + normxcorr2(sign_template(:,:,2), im_resized(:,:,2));
    correlation = correlation + normxcorr2(sign_template(:,:,3), im_resized(:,:,3));
    correlation = correlation./3;
    
    [corr_height corr_width] = size(correlation);

    % Max value of an autocorrelated image is in the center.
    % Dimensions of xcorr are twice that of the original image.
    % Therefore, cut off the length/2 ends on both sides to get the
    % "middle".
    % This is our image overlay.
    resized_height = ceil(template_height/2):corr_height - floor(template_height/2);
    resized_width = ceil(template_width/2):corr_width - floor(template_width/2);
    corr_resized = correlation(resized_height, resized_width);
    corr_max = max(max(corr_resized));
    
    % Find the x and y indices that correspond to the best overlay.
    [x, y] = find(corr_resized == corr_max);
    
    corr_results = [corr_results; i corr_max x y];
end

backup = corr_results;
% Find the peaks with a minimum correlation above 2 standard deviations
corr_std_harsh = mean(corr_results(:,2)) + 1.5 * std(corr_results(:,2));
[pks, inds] = findpeaks(corr_results(:, 2), 'minpeakheight', corr_std_harsh);

% if 1.5 std-devs was too harsh, try 1
if isempty(pks)
    corr_std_light = mean(corr_results(:,2)) + std(corr_results(:,2));
    [pks, inds] = findpeaks(corr_results(:, 2), 'minpeakheight', corr_std_light);
end

% if 1 std-dev was too harsh, give up
if isempty(pks)
    ret = []
    return
end

corr_results = corr_results(inds,:);

 plot(backup(:,1), backup(:,2), 'color', 'b', 'LineWidth', 4);
 sign_title = strcat('Scale Percentage');
 title(sign_title)
 axis([ratio_major, 1, 0 ,1])

% Convert the "resized coordinates" into "original coordinates"
corr_results(:, 3) = corr_results(:, 3) .* (1 ./ corr_results(:,1));
corr_results(:, 4) = corr_results(:, 4) .* (1 ./ corr_results(:,1));


% Now I want to remove redundant peaks. Find the "best" peak, and prune out
% all other peaks within the stop sign area (as a circle).
corr_results_pruned = [];

done = 0;
while ~done
   [max_result_corr max_result_index] = max(corr_results(:,2));
   max_result = corr_results(max_result_index, :);
   
   % Add the max to the pruned results list, trm the remaining
   corr_results_pruned = [corr_results_pruned; + max_result];
   corr_results(max_result_index, :) = [];
   
   mr_x = max_result(3);
   mr_y = max_result(4);
   
   [num_results elements_per_result] = size(corr_results);
   % Remove all other results within the "stop sign" area of the best
   % result.
   i = 1;
   while i <= num_results
      check_result = corr_results(i, :);
      d = sqrt((check_result(3) - mr_x)^2 + (check_result(4) - mr_y)^2);
      if d < (prune_dim * max_result(1))
          corr_results(i, :) = []
          num_results = num_results - 1;
      else
        i = i + 1;
      end
   end
   
   % If everything's been kept or pruned, we're done here.
   % If not, we'll go again with the next max.
   if isempty(corr_results)
       done = 1;
   end
end
    
% Assign return value
ret = corr_results_pruned;
end