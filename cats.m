function cats(varargin)
% Tumor segmetation using GRF semi-supervised learning
% Author: XU Kaibin, Brainnetome Center, Institute Automation, Chinese Academy of
% Sciences
% Created at: 2016-01-21
% Lastest update: 2016-11-06
% Version: 0.2
% Any questions please contact kaibin.xu@nlpr.ia.ac.cn
% Reference: Zhu Xiaojin, 2003, Semi-Supervised Learning Using Gaussian Fields and Harmonic Functions

if(ispc), UserName = getenv('USERNAME'); else UserName = getenv('USER'); end
Version  = regexpi(help(mfilename),'Version: ([0-9]+\.[0-9]+)','tokens','once');
Datetime = fix(clock);
fprintf('*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*\n');
fprintf('*  Welcome: %s, %.4d-%.2d-%.2d %.2d:%.2d \n', UserName, Datetime(1),...
            Datetime(2), Datetime(3), Datetime(4), Datetime(5));
fprintf('*  Computer Aid Tumor Segmentation (CATS)\n');
fprintf('*  Version = %s\n', Version{1});
fprintf('*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*\n\n');

help_str = sprintf([...
                    'Keyboard & Mouse functions:\n',...
                    'h: help window\n',...
                    'i: open a new nifti file (*.nii, *.img, *.nii.gz)\n',...
                    'left mouse draw: mark foreground with green brush\n',...
                    'right mouse draw: mark background with red brush\n',...
                    'f: specify a mask of ROI to reduce computation\n',...
                    'c: clean label and masks of the current slice\n',...
                    'a, d, leftarrow, rightarrow: adjust brush size\n',...
                    'w, s, uparrow, downarrow, wheelup, wheeldown: change slice\n',...
                    '+, -: adjust fill hole size\n',...
                    't: switch among different semi-supervised learning methods\n',...
                    'r: run semi-supervised learning to segment tumor on the current slice\n',...
                    'm: show/hide masks\n',...
                    'o: output to a mask file\n',...
                    'Hint: select checkboxes to change view along with the main image\n']);
fprintf('%s', help_str);

pth_tmp = brant_fileparts(which(mfilename));
addpath(genpath(fullfile(pth_tmp, 'NIfTI_20140122')));

if nargin ~= 1    
    img_fn = fullfile(pth_tmp, 'example', 't2.nii.gz');
else
    img_fn = varargin{1};
end

fig_size = [1100, 700];
h_fig = figure('Position', [50, 10, fig_size],...
               'Name', 'Computer Aid Tumor Segmentation (CATS)',...
               'ToolBar', 'none',...
               'MenuBar', 'none',...
               'NumberTitle', 'off');

init_figure(h_fig, fig_size, help_str, img_fn);

function init_figure(h_fig, fig_size, help_str, img_fn)

[pth, fn, ext] = brant_fileparts(img_fn); %#ok<ASGLU>

fill_thres = 100;
rad_pen = 3;
gcf_pos = get(gcf, 'Position');
y_pos_top = gcf_pos(4) - 30;
mask_toggle = 'on';

switch(ext)
    case {'.jpg', '.bmp', '.png'}
        img_data = imread(img_fn);
        org_data = img_data;
        current_slice = 1;
        num_slice = 1;
        
    case {'.nii', '.hdr', '.img', '.nii.gz'}
        org_data = load_untouch_nii_mod(img_fn);
                
        org_data.img = uint16(org_data.img);
        org_data.hdr.dime.glmax = org_data.hdr.dime.glmax / 2;
        
        size_data = size(org_data.img);
        current_slice = ceil(size_data(3) / 2);
        img_data = org_data.img(:, :, current_slice);
        img_data = rot90(uint16(65535 * single(img_data) / org_data.hdr.dime.glmax));
        
        num_slice = size_data(3);
end

label_mask = cell(num_slice, 1);
ssl_mask = cell(num_slice, 1);
filled_ssl_mask = cell(num_slice, 1);
ssl_feature_mask = cell(num_slice, 1);
blue_mask = cell(num_slice, 1);

size_img = size(img_data);
ssl_toggle = 'GRF';

off_shift = 8;

fig_ui_text = {...
    ['filename:', 32, img_fn], [20, y_pos_top, 300, 20], 'img_hdr', org_data, 'on';...
    ['fill holes <', 32, num2str(fill_thres, '%d voxels')], [20, y_pos_top - 20 * 1, 80, 20], 'fill_thres', fill_thres, 'on';...
    ['brush size:', 32, num2str(rad_pen, '%d')], [20, y_pos_top - 20 * 2, 80, 20], 'pen_radius', rad_pen, 'on';...
    ['slice:', 32, num2str(current_slice, '%d')], [20, y_pos_top - 20 * 3, 80, 20], 'slice_num', current_slice, 'on';...
    ssl_toggle, [20, y_pos_top - 20 * 4, 10, 20], 'ssl_toggle', ssl_toggle, 'on';...
    'ssl_mask', [20, y_pos_top - 20 * off_shift, 10, 20], 'ssl_mask', ssl_mask, 'off';...
    'filled_ssl_mask', [20, y_pos_top - 20 * (off_shift+1), 10, 20], 'filled_ssl_mask', filled_ssl_mask, 'off';...
    'ssl_feature_mask', [20, y_pos_top - 20 * (off_shift+2), 10, 20], 'ssl_feature_mask', ssl_feature_mask, 'off';...
    'blue_mask', [20, y_pos_top - 20 * (off_shift+3), 10, 20], 'blue_mask', blue_mask, 'off';...
    'label_mask', [20, y_pos_top - 20 * (off_shift+4), 10, 20], 'label_mask', label_mask, 'off';...
    'slice_size', [20, y_pos_top - 20 * (off_shift+5), 10, 20], 'slice_size', size_img, 'off';...
    'help_info', [20, y_pos_top - 20 * (off_shift+6), 10, 20], 'help_info', help_str, 'off';...
    'mask_toggle', [20, y_pos_top - 20 * (off_shift+7), 10, 20], 'mask_toggle', mask_toggle, 'off';...
    
    };
create_ui(fig_ui_text, 'text', h_fig);

pos_tmp = zeros(6, 4);
subplot(2, 3, 1);
plot_pts_masks(img_data, [], 'blue_mask');
pos_tmp(1, :) = get(gca, 'Position');
for m = 2:6
    subplot(2, 3, m);
    plot_pts_masks(img_data, [], 'ssl_mask');
    pos_tmp(m, :) = get(gca, 'Position');
end

pos_axis = bsxfun(@times, pos_tmp(:, 1:2), fig_size);
size_axis = bsxfun(@times, pos_tmp(:, 3:4), fig_size);

y_shift = 8;
fig_ui_chb = {...
    'SSL raw mask', [pos_axis(2, 1), pos_axis(2, 2) + size_axis(2, 2) + y_shift, 100, 20], 'ssl_mask_ind', 0, '';...
    'processed SSL mask', [pos_axis(3, 1), pos_axis(3, 2) + size_axis(3, 2) + y_shift, 100, 20], 'filled_ssl_mask_ind', 1, '';...
    'feature', [pos_axis(4, 1), pos_axis(4, 2) + size_axis(4, 2) + y_shift, 100, 20], 'feature_ind', 0, '';...
    'SSL raw results', [pos_axis(5, 1), pos_axis(5, 2) + size_axis(5, 2) + y_shift, 100, 20], 'ssl_masked_img_ind', 0, '';...
    'processed SSL results', [pos_axis(6, 1), pos_axis(6, 2) + size_axis(6, 2) + y_shift, 100, 20], 'filled_ssl_masked_img_ind', 0, '';...
    };
create_ui(fig_ui_chb, 'checkbox', h_fig);

set(gcf, 'WindowButtonUpFcn', @settool_up)
set(gcf, 'WindowButtonDownFcn', @settool_down)
set(gcf, 'WindowKeyReleaseFcn', @windows_cb)
set(gcf, 'WindowScrollWheelFcn', @windows_cb);

function windows_cb(obj, evd)
% Callback of pressed keys
% f to create blue mask (region of interests)
% c to clean the current labels and results
% w, s, uparrow, downarrow and wheelscroll to change slice
% a, d, leftarrow, rightarrow to change brush size

if verLessThan('matlab', '8.4') == 1
    if isfield(evd, 'Key')
        evd_str = evd.Key;
    elseif isfield(evd, 'VerticalScrollCount')
        if evd.VerticalScrollCount == 1
            evd_str = 'WindowScrollDown';
        else
            evd_str = 'WindowScrollUp';
        end
    else
        error('Unknown Operation!');
    end
else
    % for matlab 2014b and higher
    if strcmp(evd.EventName, 'WindowKeyRelease')
        evd_str = evd.Key;
    elseif strcmp(evd.EventName, 'WindowScrollWheel')
        if evd.VerticalScrollCount == 1
            evd_str = 'WindowScrollDown';
        else
            evd_str = 'WindowScrollUp';
        end
    else
        error('Unknown Operation!');
    end
end

h_fig = gcf;

h_fill_thres = findobj(h_fig, 'Tag', 'fill_thres');
fill_thres = get(h_fill_thres, 'Userdata');

h_pen_size = findobj(h_fig, 'Tag', 'pen_radius');
pen_size = get(h_pen_size, 'Userdata');

h_img_hdr = findobj(obj, 'Tag', 'img_hdr');
img_data_org = get(h_img_hdr, 'Userdata');

h_c_slice = findobj(obj, 'Tag', 'slice_num');
c_slice = get(h_c_slice, 'Userdata');

h_label_mask = findobj(gcf, 'Tag', 'label_mask');
label_masks = get(h_label_mask, 'Userdata');

h_blue_mask = findobj(gcf, 'Tag', 'blue_mask');
blue_masks = get(h_blue_mask, 'Userdata');

h_ssl_mask = findobj(gcf, 'Tag', 'ssl_mask');
ssl_masks = get(h_ssl_mask, 'Userdata');

h_filled_ssl_mask = findobj(gcf, 'Tag', 'filled_ssl_mask');
filled_ssl_masks = get(h_filled_ssl_mask, 'Userdata');

h_help_info = findobj(gcf, 'Tag', 'help_info');
help_str = get(h_help_info, 'Userdata');

h_mask_toggle = findobj(gcf, 'Tag', 'mask_toggle');
mask_tog_str = get(h_mask_toggle, 'Userdata');

h_ssl_toggle = findobj(gcf, 'Tag', 'ssl_toggle');
ssl_toggle = get(h_ssl_toggle, 'Userdata');

img_data = rot90(uint16(65535 * single(img_data_org.img(:, :, c_slice)) / img_data_org.hdr.dime.glmax));
size_img = size(img_data);

ssl_method_strs = {'GRF', 'LLGC'};

switch(evd_str)
    case 'h'
        fprintf(help_str);
        helpdlg(help_str);
    case 't'
        ssl_mtd_now = find(strcmpi(ssl_toggle, ssl_method_strs));
        ssl_mtd_next_ind = ssl_mtd_now + 1;
        if ssl_mtd_next_ind > numel(ssl_method_strs)
            ssl_mtd_next_ind = 1;
        end
        ssl_mtd_next = ssl_method_strs{ssl_mtd_next_ind};
        set(h_ssl_toggle, 'Userdata', ssl_mtd_next, 'String', ssl_mtd_next);
        return;
    case 'i'
        [file_tmp, path_tmp] = uigetfile({'*.nii;*.nii.gz;*.img', 'NIFTI files (*.nii;*.nii.gz;*.img)'});
        if ~isnumeric(file_tmp)
            img_fn = fullfile(path_tmp, file_tmp);
            fig_size = get(h_fig, 'Position');
            init_figure(h_fig, fig_size(3:4), help_str, img_fn);
        end
        return;
    case 'o'
        org_fn = strrep(get(h_img_hdr, 'String'), 'filename: ', '');
        [pth, fn, ext] = brant_fileparts(org_fn);
        
        out_masks_tot = cell2volume(filled_ssl_masks, size_img, 3);
        data_cvt_fun = str2func(class(img_data_org.img));
        img_data_org.img = data_cvt_fun(out_masks_tot);
        outfn = fullfile(pth, [fn, '_mask', ext]);
        save_untouch_nii(img_data_org, outfn);
        
        out_blue_tot = cell2volume(blue_masks, size_img, 3);
        data_cvt_fun = str2func(class(img_data_org.img));
        img_data_org.img = data_cvt_fun(out_blue_tot);
        outfn_blue = fullfile(pth, [fn, '_blue_mask', ext]);
        save_untouch_nii(img_data_org, outfn_blue);
        
        out_label_tot = cell2volume(label_masks, size_img, 3);
        data_cvt_fun = str2func(class(img_data_org.img));
        img_data_org.img = data_cvt_fun(out_label_tot == 1);
        outfn_tumor = fullfile(pth, [fn, '_label_tumor', ext]);
        save_untouch_nii(img_data_org, outfn_tumor);
        
        img_data_org.img = data_cvt_fun(out_label_tot == 2);
        outfn_bg = fullfile(pth, [fn, '_label_bg', ext]);
        save_untouch_nii(img_data_org, outfn_bg);
        
        fprintf('Mask and labels have been saved to\n%s\n%s\n%s\n%s\n', outfn, outfn_blue, outfn_tumor, outfn_bg)
        helpdlg(sprintf('Mask and labels have been saved to\n%s\n%s\n%s\n%s', outfn, outfn_blue, outfn_tumor, outfn_bg));
        
    case 'r'
        ssl_methods(img_data, label_masks{c_slice}, blue_masks{c_slice}, ssl_toggle);
        set(h_mask_toggle, 'Userdata', 'on');
        return;
    case 'g'
        blue_masks{c_slice} = [];
        
        subplot(2, 3, 1);
        plot_pts_masks(img_data, blue_masks{c_slice}, 'blue_mask');
        plot_pts_masks([], label_masks{c_slice}, 'label');
    case 'c'
        
        label_masks{c_slice} = [];
        blue_masks{c_slice} = [];
        ssl_masks{c_slice} = [];
        filled_ssl_masks{c_slice} = [];
        
        subplot(2, 3, 1);
        plot_pts_masks(img_data, blue_masks{c_slice}, 'blue_mask');
        
        subplot(2, 3, 2);
        plot_pts_masks(img_data, ssl_masks{c_slice}, 'ssl_mask');
        
        subplot(2, 3, 3);
        plot_pts_masks(img_data, filled_ssl_masks{c_slice}, 'filled_ssl_mask');
        
        subplot(2, 3, 4);
        plot_pts_masks(img_data, label_masks{c_slice}, 'label_masked');

        subplot(2, 3, 5);
        plot_pts_masks(img_data, ssl_masks{c_slice}, 'masked_img');
        
        subplot(2, 3, 6);
        plot_pts_masks(img_data, ssl_masks{c_slice}, 'masked_img');
        
    case {'uparrow', 'downarrow', 'w', 's', 'WindowScrollDown', 'WindowScrollUp'}
        
        size_data = size(img_data_org.img);
        if any(strcmp(evd_str, {'w', 'uparrow', 'WindowScrollUp'}))
            if c_slice < size_data(3), c_slice = c_slice + 1; else return; end
        else
            if c_slice > 1, c_slice = c_slice - 1; else return; end
        end
        
        img_data = rot90(uint16(65535 * single(img_data_org.img(:, :, c_slice)) / (img_data_org.hdr.dime.glmax)));
        subplot(2, 3, 1);
        plot_pts_masks(img_data, blue_masks{c_slice}, 'blue_mask');
        plot_pts_masks([], label_masks{c_slice}, 'label');
        
        sub_plot_inds = get_subplot_ind({'ssl_mask_ind', 'filled_ssl_mask_ind', 'feature_ind', 'ssl_masked_img_ind', 'filled_ssl_masked_img_ind'});

        if sub_plot_inds(1) == 1
            subplot(2, 3, 2);
            plot_pts_masks(img_data, ssl_masks{c_slice}, 'green_mask');
        end
        
        if sub_plot_inds(2) == 1
            subplot(2, 3, 3);
            plot_pts_masks(img_data, filled_ssl_masks{c_slice}, 'green_mask');
        end
        
        if sub_plot_inds(3) == 1
            subplot(2, 3, 4);
            plot_pts_masks(img_data, label_masks{c_slice}, 'masked_img');
        end
        
        if sub_plot_inds(4) == 1
            subplot(2, 3, 5);
            plot_pts_masks(img_data, ssl_masks{c_slice}, 'masked_img');
        end
        
        if sub_plot_inds(5) == 1
            subplot(2, 3, 6);
            plot_pts_masks(img_data, filled_ssl_masks{c_slice}, 'masked_img');
        end
    case 'm'
        sub_plot_inds = get_subplot_ind({'ssl_mask_ind', 'filled_ssl_mask_ind', 'feature_ind', 'ssl_masked_img_ind', 'filled_ssl_masked_img_ind'});
        
        if strcmp(mask_tog_str, 'off')
            if sub_plot_inds(1) == 1
                subplot(2, 3, 2);
                plot_pts_masks(img_data, ssl_masks{c_slice}, 'green_mask');
            end

            if sub_plot_inds(2) == 1
                subplot(2, 3, 3);
                plot_pts_masks(img_data, filled_ssl_masks{c_slice}, 'green_mask');
            end
            mask_tog_str = 'on';
        else
            if sub_plot_inds(1) == 1
                subplot(2, 3, 2);
                plot_pts_masks(img_data, ssl_masks{c_slice}, 'image_org');
            end

            if sub_plot_inds(2) == 1
                subplot(2, 3, 3);
                plot_pts_masks(img_data, filled_ssl_masks{c_slice}, 'image_org');
            end
            mask_tog_str = 'off';
        end
        
    case 'f'
        subplot(2, 3, 1);
        rect_org = getrect;
        rect_org_int = round(rect_org);
        
        
        img_mask_tmp = false(size_img([1, 2]));
        
        org_pts = max(1, rect_org_int(1:2));
        end_pts = min(size_img([2, 1]), rect_org_int(3:4) + org_pts + (rect_org_int(1:2) - 2) .* (rect_org_int(1:2) < 0));
        
        img_mask_tmp(org_pts(2):end_pts(2), org_pts(1):end_pts(1)) = true;
        
        % initialize blue_mask if empty
        if isempty(blue_masks{c_slice})
            blue_masks{c_slice} = zeros(size_img, 'uint16');
        end
        blue_masks{c_slice} = blue_masks{c_slice} | img_mask_tmp;
        
        plot_pts_masks(img_data, blue_masks{c_slice}, 'blue_mask');
        plot_pts_masks([], label_masks{c_slice}, 'label');
    case {'add', 'equal'}
        fill_thres = fill_thres + 10;
    case {'subtract', 'hyphen'}
        if fill_thres > 10, fill_thres = fill_thres - 10; end
        
    case {'d', 'rightarrow'}
        pen_size = pen_size + 1;
        
    case {'a', 'leftarrow'}
        if pen_size > 1, pen_size = pen_size - 1; end
end

set(h_fill_thres, 'Userdata', fill_thres, 'String', ['fill holes <', 32, num2str(fill_thres, '%d voxels')]);
set(h_pen_size, 'Userdata', pen_size, 'String', ['brush size:', 32, num2str(pen_size)]);
set(h_c_slice, 'String', ['slice:', 32, num2str(c_slice)], 'Userdata', c_slice);
set(h_label_mask, 'Userdata', label_masks);
set(h_blue_mask, 'Userdata', blue_masks);
set(h_ssl_mask, 'Userdata', ssl_masks);
set(h_filled_ssl_mask, 'Userdata', filled_ssl_masks);
set(h_mask_toggle, 'Userdata', mask_tog_str);

function out_vol = cell2volume(cell_vec, size_img, rot_ind)

for m = 1:numel(cell_vec)
    if isempty(cell_vec{m})
        cell_vec{m} = false(size_img)';
    else
        cell_vec{m} = rot90(cell_vec{m}, rot_ind);
    end
end
out_vol = cat(3, cell_vec{:});

function vals = get_subplot_ind(sub_tags)
h_sub_tags = cellfun(@(x) findobj(gcf, 'Tag', x), sub_tags, 'UniformOutput', false);
vals = cellfun(@(x) get(x, 'Value'), h_sub_tags);

function plot_pts_masks(img_data, input_mask, opt)
% plot_masks at different axis

switch(opt)
    case 'image_org'
        imshow(img_data);
        axis('on');
    case 'label'
        if ~isempty(input_mask)
            color_pts = {'g.', 'r.'};
            hold('on');
            for m = 1:2
                [x_tmp, y_tmp] = find(input_mask == m);
                plot(y_tmp, x_tmp, color_pts{m});
            end
            hold('off');
        end
    case 'label_masked'
        if ~isempty(input_mask)
            masked_data = img_data .* uint16(input_mask ~= 0);
        else
            size_img = size(img_data);
            masked_data = zeros(size_img, 'uint16');
        end
        imshow(masked_data);
        axis('on');
    case 'blue_mask'
        if ~isempty(input_mask)
            % whether image is RGB or gray image
            size_img = size(img_data);
            if length(size_img) == 2
                img_data = cat(3, img_data, img_data, img_data + uint16((input_mask > 0) * 65535 * 0.8));
            else
                img_data(:, :, 3) = img_data(:, :, 3) + uint16(input_mask * 65535 * 0.8);
            end
        end
        imshow(img_data);
        axis('on');
    case 'green_mask'
        if ~isempty(input_mask)
            % whether image is RGB or gray image
            size_img = size(img_data);
            if length(size_img) == 2
                img_data = img_data .* 0.7;
                img_data = cat(3, img_data, img_data + uint16((input_mask > 0) * 65535 * 0.4), img_data);
            else
                img_data(:, :, 3) = img_data(:, :, 2) + uint16(input_mask * 65535 * 0.5);
            end
        end
        imshow(img_data);
        axis('on');
    case {'ssl_mask', 'filled_ssl_mask'}
        if isempty(input_mask)
            size_img = size(img_data);
            input_mask = zeros(size_img, 'uint16');    
        end
        imshow(input_mask);
        axis('on');
    
    case {'masked_img'}
        if size(img_data, 3) == 3, dim_rgb = 3; else dim_rgb = 1; end
        
        if isempty(input_mask)
            size_img = size(img_data);
            input_mask = zeros(size_img, 'uint16');    
        end
        
        imshow(img_data .* uint16(repmat(input_mask ~= 0, [1, 1, dim_rgb])));
        axis('on')
end

caxis([0, 65535]);


function settool_up(obj, evd)

set(obj, 'WindowButtonMotionFcn', '');

function settool_down(obj, evd)

set(obj, 'WindowButtonMotionFcn', @drawline);

function drawline(obj, evd) %#ok<INUSD>

h_label_mask = findobj(gcf, 'Tag', 'label_mask');
h_c_slice = findobj(obj, 'Tag', 'slice_num');
h_slice_size = findobj(obj, 'Tag', 'slice_size');

label_masks = get(h_label_mask, 'Userdata');
c_slice = get(h_c_slice, 'Userdata');
size_img = get(h_slice_size, 'Userdata');

mouse_str = get(obj, 'SelectionType');

% img_fig_data = get(obj, 'Userdata');
% img_labels = label_masks{c_slice};

C = int32(get(gca, 'CurrentPoint'));
% size_img = size(label_masks{c_slice});

h_pen_size = findobj(gcf, 'Tag', 'pen_radius');
pen_size = get(h_pen_size, 'Userdata');
[xx, yy] = ndgrid(-1 * pen_size:pen_size);
nbr_shift = int32([xx(:), yy(:)]);
C_shift = bsxfun(@plus, C(1, 1:2), nbr_shift);

C_ind = (C_shift(:, 1) > 0) & (C_shift(:, 1) < size_img(2)) &...
        (C_shift(:, 2) > 0) & (C_shift(:, 2) < size_img(1));

if all(C_ind == 0)
    return;
end

C_shift = C_shift(C_ind, :);
C_1d = sub2ind(size_img, C_shift(:, 2), C_shift(:, 1));

if isempty(label_masks{c_slice})
    label_masks{c_slice} = zeros(size_img, 'uint32');
end

switch(mouse_str)
    case 'normal'
        % left mouse click
        color_pt = 'g.';
        label_masks{c_slice}(C_1d) = 1;
    case 'alt'
        % right mouse click
        color_pt = 'r.';
        label_masks{c_slice}(C_1d) = 2;
end
% img_fig_data{1} = img_labels;
% set(obj, 'Userdata', img_fig_data);

set(h_label_mask, 'Userdata', label_masks)

title(gca, sprintf('(X,Y)=(%d,%d)', C(1,1:2)));
hold on
plot(C_shift(:, 1), C_shift(:, 2), color_pt);
hold off

function ssl_methods(img_data, img_labels, img_mask, ssl_strs)

size_img = size(img_data);
if all(img_mask(:) == false) || isempty(img_mask)
    img_mask = true(size_img(1:2));
end


subplot(2, 3, 4);
plot_pts_masks(img_data, img_labels, 'label_masked');


if size(img_data, 3) == 3, dim_rgb = 3; else dim_rgb = 1; end
img_feature = single(reshape(shiftdim(img_data, 2), dim_rgb, [])');
tic

switch(ssl_strs)
    case 'GRF'
        label_all = ssl_grf(img_mask, img_feature, img_labels);
    case 'LLGC'
        label_all = ssl_llgc(img_mask, img_feature, img_labels);
    otherwise
        error('Unknown SSL methods!');
end
toc

% get results
img_labels_out = zeros(size_img(1:2), 'uint32');
u_ind = img_mask(:);
img_labels_out(u_ind) = label_all;

%         img_labels_out(l_ind) = f_l_pre; % temp

img_labels_out(img_labels_out == 1) = 65535;
img_labels_out(img_labels_out == 2) = 0;

% sorting data
h_fill_thres = findobj(gcf, 'Tag', 'fill_thres');
h_c_sclice = findobj(gcf, 'Tag', 'slice_num');
h_blue_mask = findobj(gcf, 'Tag', 'blue_mask');
h_ssl_mask = findobj(gcf, 'Tag', 'ssl_mask');
h_filled_ssl_mask = findobj(gcf, 'Tag', 'filled_ssl_mask');

fill_thres = get(h_fill_thres, 'Userdata');
c_slice = get(h_c_sclice, 'Userdata');
blue_masks = get(h_blue_mask, 'Userdata');
ssl_masks = get(h_ssl_mask, 'Userdata');
filled_ssl_masks = get(h_filled_ssl_mask, 'Userdata');

if ~isempty(blue_masks{c_slice})
    img_labels_out = img_labels_out .* uint32(blue_masks{c_slice});
end

ssl_masks{c_slice} = img_labels_out;

subplot(2, 3, 2);
plot_pts_masks(img_data, ssl_masks{c_slice}, 'green_mask');

subplot(2, 3, 5);
plot_pts_masks(img_data, ssl_masks{c_slice}, 'masked_img');

ssl_clusters = bwlabeln(img_labels_out);
uniq_fg = setdiff(unique(ssl_clusters(img_labels == 1)), 0);

if any(uniq_fg)
    ssl_clusters_bw = arrayfun(@(x) ssl_clusters == x, uniq_fg, 'UniformOutput', false);
    bw_tot_tmp = cat(3, ssl_clusters_bw{:});
    bw_tot = sum(bw_tot_tmp, 3);

    bw_tot = ~bwareaopen(~bw_tot, fill_thres, 4);

    filled_ssl_masks{c_slice} = bw_tot;
else
    filled_ssl_masks{c_slice} = [];
end

subplot(2, 3, 3);
plot_pts_masks(img_data, filled_ssl_masks{c_slice}, 'green_mask');

subplot(2, 3, 6);
plot_pts_masks(img_data, filled_ssl_masks{c_slice}, 'masked_img');

set(h_ssl_mask, 'Userdata', ssl_masks);
set(h_filled_ssl_mask, 'Userdata', filled_ssl_masks);


function label_all = ssl_llgc(img_mask, img_feature, img_labels)

img_feature = img_feature / 65535;

u_ind = img_mask(:);
u_data = img_feature(u_ind, :);

l_ind = img_labels(:) ~= 0;
l_data = img_feature(l_ind, :);
ll_dist = squareform(pdist(l_data, @distfun));

f_l_pre = img_labels(l_ind);
lbls = unique(f_l_pre);
fl_tmp = arrayfun(@(x) f_l_pre == x, lbls, 'UniformOutput', false);
fl = cat(2, fl_tmp{:});

block_size = 512 / 2;
% block_size = size(u_data, 1);
num_udata = size(u_data, 1);
int_array = get_intervals(1, num_udata, block_size);
if any(diff(int_array(end, :)) == 0)
    int_array(end-1, 2) = int_array(end-1, 2) + 1;
    int_array(end, :) = [];
end

% u_data_sort = sort(u_data, 'ascend');
rand_pixels = randperm(num_udata);
% rand_pixels = 1:num_udata;

% num_l = size(ll_dist, 1);
delta = 0.3;
alpha_llgc = 0.99;
label_all = zeros(size(u_data, 1), 1);

for m = 1:size(int_array, 1)
    ind_vec = rand_pixels(int_array(m, 1):int_array(m, 2));
    block_size_tmp = length(ind_vec);
    fprintf('Processing block %d/%d, block size: %d\n', m, size(int_array, 1), block_size_tmp);
    u_data_tmp = u_data(ind_vec, :);

    lu_dist = pdist2(l_data, u_data_tmp);
    uu_dist = squareform(pdist(u_data_tmp, @distfun));
%             disp([max(ll_dist(:)), max(lu_dist(:)), max(uu_dist(:))]);

    dist_all = [uu_dist, lu_dist'; lu_dist, ll_dist];
    W = exp(-1 * dist_all / (2 * delta ^ 2));
%     W_up = squareform(W-eye(size( W)));
%     disp([min(W_up(:)), max(W_up(:))]);
    D = diag(sum(W));

    u_vec = 1:block_size_tmp;
%     l_vec = (block_size_tmp + 1):(block_size_tmp + num_l);
    
    S = D ^ (-0.5) * W * (D) ^ (-0.5);
    F = (1 - alpha_llgc) * (eye(size(S)) - alpha_llgc * S) \ [zeros(block_size_tmp, 2); fl];
    fu = F(u_vec, :);

%     fu = (D(u_vec, u_vec) - W(u_vec, u_vec)) \ W(u_vec, l_vec) * fl;
    
%     oo_d = sparse(double(D(u_vec, u_vec) - W(u_vec, u_vec)));
%     oo = sparse(double(W(u_vec, l_vec)));
%     fu = oo_d \ oo * fl;
%     toc
    
    [~, max_loc] = max(fu, [], 2);
    label_all(ind_vec) = lbls(max_loc);
end


% sq_dist = squareform(dist_d);
% W = exp(-1 * sq_dist / (2 * delta ^ 2));
% D = diag(sum(W));
% S = D ^ (-0.5) * W * (D) ^ (-0.5);
% F = (1 - alpha_llgc) * (eye(size(S)) - alpha_llgc * S) \ fl;
% label_all = F(~sel_sam_mask, :);

function label_all = ssl_lsr(img_mask, img_feature, img_labels)

img_feature = img_feature / 65535;

u_ind = img_mask(:);
u_data = img_feature(u_ind, :);

l_ind = img_labels(:) ~= 0;
l_data = img_feature(l_ind, :);
ll_dist = squareform(pdist(l_data, @distfun));

f_l_pre = img_labels(l_ind);
% lbls = unique(f_l_pre);
% fl_tmp = arrayfun(@(x) f_l_pre == x, lbls, 'UniformOutput', false);
% fl = cat(2, fl_tmp{:});

block_size = 512 / 2;
% block_size = size(u_data, 1);
num_udata = size(u_data, 1);
int_array = get_intervals(1, num_udata, block_size);
if any(diff(int_array(end, :)) == 0)
    int_array(end-1, 2) = int_array(end-1, 2) + 1;
    int_array(end, :) = [];
end

% u_data_sort = sort(u_data, 'ascend');
rand_pixels = randperm(num_udata);
% rand_pixels = 1:num_udata;

num_l = size(ll_dist, 1);
% delta = 100; % for uint32, 5 for uint8
label_all = zeros(size(u_data, 1), 1);
num_nbr = 25;
reg_nbr = 0.0001 * eye(num_nbr);

for m = 1:size(int_array, 1)
    ind_vec = rand_pixels(int_array(m, 1):int_array(m, 2));
    block_size_tmp = length(ind_vec);
    fprintf('Processing block %d/%d, block size: %d\n', m, size(int_array, 1), block_size_tmp);

    data_all_tmp = [l_data; u_data(ind_vec, :)];
    n_data = size(data_all_tmp, 1);
    
    knn_all = knnsearch(data_all_tmp, data_all_tmp, 'K', num_nbr);
    knn_all(:, 1) = 1:n_data;
    data_with_nbr = data_all_tmp(knn_all);
    
    d = 1;
    M = 0;
    gamma_global = 10000.0;
    for i = 1:size(data_with_nbr, 1)
        P_i = data_with_nbr(i, :);
        K_i = squareform(pdist(P_i', @distfun));
        
        e = [ones(1, num_nbr); P_i];
        coef_mat = [reg_nbr + K_i, e'; e, zeros(d + 1)];
        
        p_tmp = pinv(coef_mat);                        
        M_i = p_tmp(1:num_nbr, 1:num_nbr);
        S_i = false(num_nbr, n_data);
        s_ind = sub2ind([num_nbr, n_data], (1:num_nbr)', knn_all(i,:)');
        S_i(s_ind) = true;
        
        M = M + S_i' * M_i * S_i;
    end
    
    D = diag([ones(num_l, 1); zeros(block_size_tmp, 1)]);
    Y = [f_l_pre == 1 + (f_l_pre == 2) * 1; zeros(block_size_tmp, 1)];
    F = (M + gamma_global * D) \ D * Y * gamma_global;
    
    label_all(ind_vec) = F(size(l_data,1)+1:end) >= 0;
end

function label_all = ssl_grf(img_mask, img_feature, img_labels)

img_feature = img_feature / 65535;

u_ind = img_mask(:);
u_data = img_feature(u_ind, :);

l_ind = img_labels(:) ~= 0;
l_data = img_feature(l_ind, :);
ll_dist = squareform(pdist(l_data, @distfun));

f_l_pre = img_labels(l_ind);
lbls = unique(f_l_pre);
fl_tmp = arrayfun(@(x) f_l_pre == x, lbls, 'UniformOutput', false);
fl = cat(2, fl_tmp{:});

block_size = 512 / 2;
% block_size = size(u_data, 1);
num_udata = size(u_data, 1);
int_array = get_intervals(1, num_udata, block_size);
if any(diff(int_array(end, :)) == 0)
    int_array(end-1, 2) = int_array(end-1, 2) + 1;
    int_array(end, :) = [];
end

% u_data_sort = sort(u_data, 'ascend');
rand_pixels = randperm(num_udata);
% rand_pixels = 1:num_udata;

num_l = size(ll_dist, 1);
delta = 0.3; % for uint32, 5 for uint8
label_all = zeros(size(u_data, 1), 1);

for m = 1:size(int_array, 1)
    ind_vec = rand_pixels(int_array(m, 1):int_array(m, 2));
    block_size_tmp = length(ind_vec);
    fprintf('Processing block %d/%d, block size: %d\n', m, size(int_array, 1), block_size_tmp);
    u_data_tmp = u_data(ind_vec, :);

    lu_dist = pdist2(l_data, u_data_tmp);
    uu_dist = squareform(pdist(u_data_tmp, @distfun));
%             disp([max(ll_dist(:)), max(lu_dist(:)), max(uu_dist(:))]);

    dist_all = [uu_dist, lu_dist'; lu_dist, ll_dist];
    W = exp(-1 * dist_all / (2 * delta ^ 2));
%     W_up = squareform(W-eye(size( W)));
%     disp([min(W_up(:)), max(W_up(:))]);
    D = diag(sum(W));

    u_vec = 1:block_size_tmp;
    l_vec = (block_size_tmp + 1):(block_size_tmp + num_l);
    
    
    fu = (D(u_vec, u_vec) - W(u_vec, u_vec)) \ W(u_vec, l_vec) * fl;
    
%     oo_d = sparse(double(D(u_vec, u_vec) - W(u_vec, u_vec)));
%     oo = sparse(double(W(u_vec, l_vec)));
%     fu = oo_d \ oo * fl;
%     toc
    
    [~, max_loc] = max(fu, [], 2);
    label_all(ind_vec) = lbls(max_loc);
end


function int_array = get_intervals(start_pt, end_pt, len_int)
% works only for integer
% start_pt: start point
% end_pt: end point
% len_int: length of interval

assert(start_pt < end_pt);

num_pts = end_pt - start_pt + 1;

num_blk = ceil(double(num_pts) / double(len_int));

int_tmp = start_pt:len_int:end_pt;
int_array = zeros(num_blk, 2);
for m = 1:num_blk
    if m == num_blk
        int_array(m, :) = [int_tmp(m), min(end_pt, int_tmp(m) + len_int - 1)];
    else
        int_array(m, :) = [int_tmp(m), int_tmp(m) + len_int - 1];
    end
end

function h_out = create_ui(uiOpt, uiStyle, uiParent)

h_out = cell(size(uiOpt, 1), 1);

for n = 1:size(uiOpt, 1)
    h_ui_tmp = findobj(uiParent, 'Tag', uiOpt{n, 3});
    if ~isempty(h_ui_tmp)
        delete(h_ui_tmp);
    end
end

switch(uiStyle)
    case {'text'}
        for n = 1:size(uiOpt, 1)
            h_out{n} = uicontrol(...
                'Parent',               uiParent,...
                'Units',                'pixels',...
                'String',               uiOpt{n, 1},...
                'Position',             uiOpt{n, 2},...
                'Tag',                  uiOpt{n, 3},...
                'Userdata',             uiOpt{n, 4},...
                'Visible',              uiOpt{n, 5},...
                'Style',                uiStyle,...
                'HorizontalAlignment',  'left',...
                'FontSize',             10);
            resize_ui(h_out{n});
            set(h_out{n}, 'Units', 'Normalized');
        end
    
    case {'checkbox', 'radiobutton'}
        for n = 1:size(uiOpt, 1)
            h_out{n} = uicontrol(...
                'Parent',           uiParent,...
                'Units',            'pixels',...
                'HorizontalAlignment',  'left',...
                'String',           uiOpt{n, 1},...
                'Position',         uiOpt{n, 2},...
                'Tag',              uiOpt{n, 3},...
                'Value',            uiOpt{n, 4},...
                'Callback',         uiOpt{n, 5},...
                'Style',            uiStyle);
            resize_ui(h_out{n});
            set(h_out{n}, 'Units', 'Normalized');
        end
end

function resize_ui(h)

set(h, 'Units', 'characters');

str_ui = get(h, 'String');
if ~isempty(strfind(str_ui, '<html>'))
    rep_strs = {'<html>', '</html>', '<sup>', '</sup>', '<sub>', '</sub>'};
    str_ui_new = str_ui;
    for m = 1:numel(rep_strs)
        str_ui_new = strrep(str_ui_new, rep_strs{m}, '');
    end
    por_str = length(str_ui_new) / length(str_ui);
else
    por_str = 1;
end

pos_ui = get(h, 'Pos');
str_size = get(h, 'extent');
set(h, 'Position', [pos_ui(1:2), por_str * str_size(3) + 3, pos_ui(4)]);
set(h, 'Units', 'Normalized');

function dist_vec = distfun(x1, x2)
% x1: 1*N vector
% x2: M2*N matrix
% for 1d data
dist_vec = abs(bsxfun(@minus, x1, x2));
% dist_vec = sum(diff_vec .^ 2, 2);