function c_fft = fftpoly(a, b)
    n = length(a);
    % The product have length 2n-1
    N = 2*n - 1;
    Nfft = 2^(nextpow2(N)); % Next power of 2 >= N
    A = fft(a, Nfft);
    B = fft(b, Nfft);
    C = A .* B;
    c_fft = ifft(C);
    c_fft = c_fft(1:N);
end
