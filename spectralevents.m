function [specEv_struct, TFRs, X] = spectralevents(eventBand, analyze, fVec, Fs, varargin)
% SPECTRALEVENTS Find and analyze spectral events (local maxima above a 
%   power threshold) of a specified band in the non-averaged time-frequency
%   response (TFR) in a dataset.
%   [specEv_struct,TFRs,X] = SPECTRALEVENTS(eventBand,analyze,fVec,Fs,X,classLabels)
%   or
%   [specEv_struct,TFRs,X] = SPECTRALEVENTS(eventBand,analyze,fVec,Fs,X{1},classLabels{1},X{2},classLabels{2},...)
%   returns a structure array of spectral event features (specEv_struct),
%   cell array containing the time-frequency responses (TFRs), and cell 
%   array of all time-series trials (X) for each subject/session within the
%   dataset comparing various experimental conditions or outcome states 
%   corresponding to each trial.
%
% Inputs:
%   fVec - frequency vector (Hz) over which the time-frequency response (TFR) is 
%       calcuated. Note that this set must fall
%       within the range of resolvable frequency values (i.e. Fmin>=1/(trial
%       duration), Fmax<=(Nyquist freq)).
%   eventBand - range of frequencies ([Fmin_event Fmax_event]; Hz) over which above-threshold spectral
%       power events are classified.
%   Fs - sampling frequency (Hz).
%   analyze - logical value that determines whether to run basic feature 
%       analysis and output standard figures.
%   X{a} - m-by-n matrix (of the a^th subject/session cell in cell array X) 
%       representing the time-series trials of the given subject. m is the number
%       of timepoints and n is the number of trials. Note that m timepoints must 
%       be uniform across all trials and subjects.
%   classLabels{a} - trial classification labels (of the a^th subject/session
%       cell in cell array classLabels); specifies the classification label 
%       (e.g. hit or miss, detect or non-detect, attend-to or attend away) 
%       corresponding to the experimental condition of a given trial in the 
%       subject/session. If classLabels{a} is entered as a single value, 0 or 1,
%       all trials in the a^th subject/session are associated with that label. 
%       Alternatively, classLabels{a} can be entered as a vector of binary values
%       with n elements, each corresponding to a trial within the a^th subject/session.
%
% Outputs:
%   specEv_struct - array of event feature structures, each corresponding
%       with a subject/session, respectively.
%   TFRs - cell array with each cell containing the TFR for a given
%       subject/session
%   X - cell array with each cell containing the time-series trials for a
%       given subject/session
%
% See also SPECTRALEVENTS_FIND, SPECTRALEVENTS_ANALYSIS.

% Validate number of time-series (X{1}, X{2},...) and trial class label (classLabels{1}, classLabels{2},...) inputs
if nargin-4>=2
    X = varargin((1:2:numel(varargin))); %Cell array containing time-series trials by subject/session
    classLabels = varargin((2:2:numel(varargin))); %Cell array containing trial classification cells by subject/session
    if numel(varargin)==2 && iscell(X{1})
        X = X{1}; 
        classLabels = classLabels{1};
    elseif mod(numel(varargin),2)~=0
        error('Must specify classification labels alongside each subject/session dataset!')
    end
else
    error('Must input at least one time-series dataset and its corresponding trial classification label/vector!')
end

% Validate format of trial class labels and reformat if necessary
numSubj = numel(X); %Number of subjects/sessions
for subj_i=1:numSubj
    if numel(classLabels{subj_i})==1
        classLabels{subj_i} = ones(1,size(X{subj_i},2))*classLabels{subj_i}; %Reformat if entered as single values instead of vectors
    elseif isequal(size(classLabels{subj_i}),[size(X{subj_i},2),1])
        classLabels{subj_i} = classLabels{subj_i}';
    elseif ~isequal(size(classLabels{subj_i}),[1,size(X{subj_i},2)])
        error('Trial classification labels are formatted incorrectly!')
    end
end

% Validate fVec input
Fn = Fs/2; %Nyquist frequency
dt = 1/Fs; %Sampling time interval
Fmin = 1/(size(X{1},1)*dt); %Minimum resolvable frequency
if fVec(1)<Fmin || fVec(end)>Fn || abs(fVec(2)-fVec(1))<Fmin
    error('Frequency vector includes values outside the resolvable/alias-free range.')
end

thrFOM = 6; %Factors of Median threshold (see Shin et al. eLife 2017 for details concerning this value)

% Solve for the time-frequency response (TFR) and run spectral event
% analysis on each trial within each subject/session
TFRs = {}; %Cell-array for storing the TFRs across subjects
for subj_j=1:numSubj
    TFR = []; %Matrix for storing freq-by-time-by-trial
    for trl=1:size(X{subj_j},2)
        [TFR_trl,tVec,~] = traces2TFR(X{subj_j}(:,trl),fVec,Fs,7); %Transformation calculated using a Morlet wavelet (width=7), see 4DToolbox for function details)
        TFR = cat(3,TFR,TFR_trl); %Concatenate each trial along the 3rd dimension
    end
    TFRs{subj_j} = TFR; %Append TFR for the given subject
    
    specEv_struct(subj_j) = spectralevents_find(eventBand,thrFOM,tVec,fVec,TFR,classLabels{subj_j}); %Find spectral events
end

% Run analysis and generate standard figures
if analyze==true
    spectralevents_analysis(specEv_struct,X,TFRs,tVec,fVec);
end
end