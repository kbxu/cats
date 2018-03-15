# Computer Aided Tumor Segmentation (CATS)
![octocat](https://github.com/kbxu/cats/blob/master/CATS.png)
## Operations: users would need to operate below commands in **MATLAB** after adding the scripts to search path.
1. Input a data file by pressing 'i';  
2. Scroll wheel to select a transverse slice where tumor lies.  
3. Select tumor zone using left button to draw a green line and background zone using right button to draw a read line. The thickness of lines can be adjusted using '+'/'-';  
4. Select a searching zone of tumor/ROI using 'f' to reduce calculation. 'f' can be use several times;  
5. Type 'r' to run segmentation;  
6. Type 'c' to clean the mask if the result is not good;  
7. When tumor ROIs on all slices have been segmented, press 'o' to output masks to the data folder.  

## Keyboard & Mouse functions:
h: help window;   
i: open a new nifti file (*.nii, *.img, *.nii.gz);  
left mouse draw: mark foreground with green brush;  
right mouse draw: mark background with red brush;  
f: specify a mask of ROI to reduce computation;  
c: clean label and masks of the current slice;  
a, d, leftarrow, rightarrow: adjust brush size;  
w, s, uparrow, downarrow, wheelup, wheeldown: change slice;  
+, -: adjust fill hole size;  
t: switch among different semi-supervised learning methods;  
r: run semi-supervised learning to segment tumor on the current slice;  
m: show/hide masks;  
o: output to a mask file;  
Hint: select checkboxes to change view along with the main image

To make scrolling more smooth, select only the wanted plots.
