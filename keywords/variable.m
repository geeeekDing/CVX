function varargout = matrix( nm, varargin )

%VARIABLE Declares a cvx variable.
%
%   VARIABLE x
%   where x is a valid MATLAB variable nm, declares a scalar
%   variable for the current cvx problem. A variable with that
%   name is added to the problem, and a cvx object with that
%   name is created in the current workspace. An error is
%   generated if a cvx problem isn't in the current workspace.
%
%   VARIABLE x(n1,n2,...,nk)
%   declares a vector, matrix, or array variable with dimensions
%   n1, n2, ..., nk, each of which must be positive integers.
%
%   VARIABLE x(n1,n2,...,nk) mod1 mod2 mod3 ... modp
%   declares a vector, matrix, or array with structure. The
%   modifiers mod1, mod2, ... can each be one of the following:
%       complex   symmetric   skew-symmetric   hermitian
%       skew-hermitian   toeplitz   hankel   upper-hankel
%       lower-triangular   upper-triangular   tridiagonal
%       diagonal   lower-bidiagonal   upper-bidiagonal
%   Appropriate combinations of these modifiers can be chosen
%   as well. All except "complex" require that the matrix be
%   square. If an N-D (N>2) array is specified, then the matrix
%   structure is applied to each 2-D "slice" of the array.
%
%   Examples:
%      variable x(100,100) symmetric tridiagonal
%      variable z(10,10,10)
%      variable y complex
%
%   See also VARIABLES, DUAL, DUALS.

prob = evalin( 'caller', 'cvx_problem', '[]' );
if ~isa( prob, 'cvxprob' ),
    error( 'A cvx problem does not exist in this scope.' );
end
global cvx___
p = index( prob );

%
% Step 1: separate the name from the parenthetical
%

xt = find( nm == '(' );
if isempty( xt ),
    x.name = nm;
    x.size = [1,1];
elseif nm( end ) ~= ')',
    error( sprintf( 'Invalid variable specification: %s', nm ) );
else,
    x.name = nm( 1 : xt( 1 ) - 1 );
    x.size = nm( xt( 1 ) + 1 : end - 1 );
end
if ~isvarname( x.name ),
    error( sprintf( 'Invalid variable specification: %s', nm ) );
elseif x.name( end ) == '_',
    error( sprintf( 'Invalid variable specification: %s\n   Variables ending in underscores are reserved for internal use.', nm ) );
end

%
% Step 2: Parse the size. In effect, all we do here is surround what is
% replace the surrounding parentheses with square braces and evaluate. All
% that matters is the result is a valid size vector. In particular, it
% need no be a simple comma-delimited list.
%

if ischar( x.size ),
    x.size = evalin( 'caller', [ '[', x.size, '];' ], 'NaN' );
    [ temp, x.size ] = cvx_check_dimlist( x.size, false );
    if ~temp,
        error( sprintf( [ 'Invalid variable specification: ', nm, '\n   Dimension list must be a vector of finite positive integers.' ] ) );
    end
end

%
% Step 3. Parse the structure.
%

nmods = length( varargin );
modifiers = '';
for k = 1 : length( varargin ),
    strs = varargin{k};
    if isempty( strs ),
        continue;
    elseif ~ischar( strs ) | size( strs, 1 ) ~= 1,
        error( 'Structure modifiers must be strings.' );
    end
    xt = find( strs == '(' );
    if isempty( xt ),
        nm = strs;
    elseif strs( end ) ~= ')',
        error( sprintf( 'Invalid structure modifier: %s', strs ) );
    else,
        nm = strs( 1 : xt(1) - 1 );
        strx.name = nm;
        strx.args = evalin( 'caller', [ '{', strs(xt(1)+1:xt(1)-1), '}' ], 'NaN' );
        if ~iscell( strx ),
            error( sprintf( 'Invalid structure modifier: %s', strs ) );
        end
        varargin{k} = strx;
    end
    if ~isvarname( nm ),
        error( sprintf( 'Invalid structure modifier: %s', strs ) );
    end
    modifiers = [ modifiers, ' ', strs ];
end
str = cvx_create_structure( x.size, varargin{:} );
if isempty( str ),
    error( sprintf( 'Incompatible structure modifiers:%s', modifiers ) );
end

v = newvar( prob, x.name, x.size, str );
assignin( 'caller', x.name, v );
if nargout > 0, varargout{1} = v; end

% Copyright 2005 Michael C. Grant and Stephen P. Boyd.
% See the file COPYING.txt for full copyright information.
% The command 'cvx_where' will show where this file is located.
