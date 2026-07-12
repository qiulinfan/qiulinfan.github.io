function cfoil = foil( a, b)
% FOIL algorithm for multiplying polynomials given by equal-length arrays
% of their coefficients and outputting an array of coefs of the product.
% Break arrays into left halves and right halves and recursively foil the halves.

    n = length(a);
    if n == 1
        cfoil = a * b;  % scalar multiplication; result is a 1-element vector
        return;
    end
    
    m = n/2;
    % Split each polynomial into lower and higher halves.
    % a(x) = a_left(x) + x^m * a_right(x), and similarly for b.
    a_left  = a(1:m);
    a_right = a(m+1:end);
    b_left  = b(1:m);
    b_right = b(m+1:end);
    
    % Recursively compute the three products (four products in FOIL):
    p0 = foil(a_left, b_left);      % length = 2*m - 1
    p1 = foil(a_left, b_right);       % length = 2*m - 1
    p2 = foil(a_right, b_left);       % length = 2*m - 1
    p3 = foil(a_right, b_right);      % length = 2*m - 1
    
    % Combine the results:
    % The full product is:
    %   a(x)*b(x) = p0 + x^m*(p1+p2) + x^(2*m)*p3.
    cfoil = zeros(1, 2*n - 1);
    % p0 goes in positions 1 to 2*m - 1.
    cfoil(1:(2*m - 1)) = cfoil(1:(2*m - 1)) + p0;
    % p1+p2 go in positions m+1 to m+(2*m - 1).
    cfoil(m+1 : m + (2*m - 1)) = cfoil(m+1 : m + (2*m - 1)) + (p1 + p2);
    % p3 goes in positions 2*m+1 to 2*m+(2*m - 1) = 2*n - 1.
    cfoil(2*m+1 : 2*m + (2*m - 1)) = cfoil(2*m+1 : 2*m + (2*m - 1)) + p3;
end