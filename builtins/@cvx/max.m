function z = max( x, y, dim )

%Disciplined convex/geometric programming information:
%    MAX is convex, log-log-convex, and nondecreasing in its first two
%    arguments. Thus when used in disciplined convex programs, both
%    arguments must be convex (or affine). In disciplined geometric
%    programs, both arguments must be log-convex (or log-affine).

error( nargchk( 1, 3, nargin ) );
if nargin == 2,

    %
    % max( X, Y )
    %

    sx = size( x );
    sy = size( y );
    xs = all( sx == 1 );
    ys = all( sy == 1 );
    if xs,
        sz = sy;
    elseif ys | isequal( sx, sy ),
        sz = sx;
    else
        error( 'Array dimensions must match.' );
    end

    %
    % Determine the computation methods
    %

    persistent remap
    if isempty( remap ),
        remap_1 = cvx_remap( 'real' );
        remap_1 = remap_1' * remap_1;
        remap_2 = cvx_remap( 'log-valid' )' * cvx_remap( 'nonpositive' );
        remap_3 = remap_2';
        remap_4 = cvx_remap( 'log-convex', 'real' );
        remap_4 = remap_4' * remap_4;
        remap_5 = cvx_remap( 'convex' );
        remap_5 = remap_5' * remap_5;
        remap   = remap_1 + ~remap_1 .* ...
            ( 2 * remap_2 + 3 * remap_3 + ~( remap_2 | remap_3 ) .* ...
            ( 4 * remap_4 + ~remap_4 .* ( 5 * remap_5 ) ) );
    end
    vx = cvx_classify( x );
    vy = cvx_classify( y );
    vr = remap( vx + size( remap, 1 ) * ( vy - 1 ) );
    vu = unique( vr );
    nv = length( vu );

    %
    % The cvx multi-objective problem
    %

    xt = x;
    yt = y;
    if nv ~= 1,
        z = cvx( sz, [] );
    end
    for k = 1 : nv,

        %
        % Select the category of expression to compute
        %

        if nv ~= 1,
            t = vr == vu( k );
            if ~xs,
                xt = cvx_subsref( x, t );
                sz = size( xt );
            end
            if ~ys,
                yt = cvx_subsref( y, t );
                sz = size( yt );
            end
        end

        %
        % Apply the appropriate computation
        %

        switch vu( k ),
        case 0,
            % Invalid
            error( sprintf( 'Disciplined convex programming error:\n    Cannot perform the operation max( {%s}, {%s} )', cvx_class( xt ), cvx_class( yt ) ) );
        case 1,
            % constant
            cvx_optval = max( cvx_constant( xt ), cvx_constant( yt ) );
        case 2,
            % max( log-valid, nonpositive ) (no-op)
            cvx_optval = xt;
        case 3,
            % max( nonpositive, log-valid ) (no-op)
            cvx_optval = yt;
        case 4,
            % posy
            cvx_begin
                geometric epigraph variable zt( sz );
                xt <= zt;
                yt <= zt;
            cvx_end
        case 5,
            % non-posy
            cvx_begin
                epigraph variable zt( sz );
                xt <= zt;
                yt <= zt;
            cvx_end
        otherwise,
            error( 'Shouldn''t be here.' );
        end

        %
        % Store the results
        %

        if nv == 1,
            z = cvx_optval;
        else
            z = cvx_subsasgn( z, t, cvx_optval );
        end

    end

else

    %
    % max( X, [], dim )
    %

    if nargin > 1 & ~isempty( y ),
        error( 'max with two matrices to compare and a working dimension is not supported.' );
    end
    sx = size( x );
    if nargin < 2,
        dim = cvx_default_dimension( sx );
    elseif ~cvx_check_dimension( dim ),
        error( 'Third argument must be a positive integer.' );
    end

    %
    % Determine sizes, quick exit for empty arrays
    %

    sx = [ sx, ones( 1, dim - length( sx ) ) ];
    nx = sx( dim );
    if any( sx == 0 ),
        sx( dim ) = min( sx( dim ), 1 );
        z = zeros( sx );
        return
    end
    sy = sx;
    sy( dim ) = 1;

    %
    % Type check
    %

    persistent remap2
    if isempty( remap2 ),
        remap_1 = cvx_remap( 'real' );
        remap_2 = cvx_remap( 'log-convex', 'real' );
        remap_3 = cvx_remap( 'convex' );
    end
    vx = cvx_reshape( cvx_classify( x ), sx );
    t1 = all( reshape( remap_1( vx ), sx ), dim );
    t2 = all( reshape( remap_2( vx ), sx ), dim );
    t3 = all( reshape( remap_3( vx ), sx ), dim );
    t3 = t3 & ~( t1 | t2 );
    t2 = t2 & ~t1;
    ta = t1 + ( 2 * t2 + 3 * t3 ) .* ~t1;
    nu = unique( ta( : ) );
    nk = length( nu );

    %
    % Quick exit for size 1
    %

    if nx == 1 & all( nu ),
        z = x;
        return
    end

    %
    % Permute and reshape, if needed
    %

    perm = [];
    if dim > 1 & any( sx( 1 : dim - 1 ) > 1 ),
        perm = [ dim, 1 : dim - 1, dim + 1 : length( sx ) ];
        x   = permute( x,  perm );
        sx  = permute( sx, perm );
        sy  = permute( sy, perm );
        ta  = permute( ta, perm );
        dim = 1;
    else
        perm = [];
    end
    nv = prod( sx ) / nx;
    x  = reshape( x, nx, nv );

    %
    % Perform the computations
    %

    if nk ~= 1,
        z = cvx( [ 1, nv ], [] );
    end
    for k = 1 : nk,

        if nk == 1,
            xt = x;
        else
            tt = ta == nu( k );
            xt = cvx_subsref( x, ':', tt );
            nv = nnz( tt );
        end

        switch nu( k ),
            case 0,
                error( sprintf( 'Disciplined convex programming error:\n   Invalid computation: max( {%s} )', cvx_class( xt, true, true ) ) );
            case 1,
                cvx_optval = max( cvx_constant( xt ), dim );
            case 2,
                cvx_begin
                    geometric epigraph variable zt( 1, nv )
                    xt <= ones(nx,1) * zt;
                cvx_end
            case 3,
                cvx_begin
                    epigraph variable zt( 1, nv )
                    xt <= ones(nx,1) * zt;
                cvx_end
            otherwise,
                error( 'Shouldn''t be here.' );
        end

        if nk == 1,
            z = cvx_optval;
        else
            z = cvx_subsasgn( z, tt, cvx_optval );
        end

    end

    %
    % Reverse the reshaping and permutation steps
    %

    z = reshape( z, sy );
    if ~isempty( perm ),
        z = ipermute( z, perm );
    end

end

% Copyright 2007 Michael C. Grant and Stephen P. Boyd.
% See the file COPYING.txt for full copyright information.
% The command 'cvx_where' will show where this file is located.