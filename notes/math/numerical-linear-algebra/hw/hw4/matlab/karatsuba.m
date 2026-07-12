%   karatsuba.m
%   The method computes:
%       p0 = a_left * b_left,
%       p2 = a_right * b_right,
%       p1 = (a_left+a_right) * (b_left+b_right),
%   then combines these as:
%       c = p0 + (p1 - p0 - p2)*x^(n/2) + p2*x^n.
function ckara = karatsuba(a, b)
    n = length(a);
    if n == 1
        ckara = a * b;
        return;
    end
    
    m = n/2;
    a_left  = a(1:m);
    a_right = a(m+1:end);
    b_left  = b(1:m);
    b_right = b(m+1:end);
    
    p0 = karatsuba(a_left, b_left);         % length = 2*m - 1
    p3 = karatsuba(a_right, b_right);        % length = 2*m - 1
    p1 = karatsuba(a_left + a_right, b_left + b_right);  % length = 2*m - 1
    
    mid = p1 - p0 - p3;
    
    ckara = zeros(1, 2*n - 1);
    ckara(1:(2*m - 1)) = ckara(1:(2*m - 1)) + p0;
    ckara(m+1 : m + (2*m - 1)) = ckara(m+1 : m + (2*m - 1)) + mid;
    ckara(2*m+1 : 2*m + (2*m - 1)) = ckara(2*m+1 : 2*m + (2*m - 1)) + p3;
end