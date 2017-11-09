close all
clear all
clc

n=4;
global A0 A1
A0=rand(n); A1=rand(n); I=eye(n);

nep.MMeval=@(l)  -l^2*I + A0 + A1*exp(-l);
nep.Mdd=@(j)                           ...
                (j==0)*(A0 + A1) +    ...
                (j==1)*(-A1) +          ...
                (j==2)*(-2*I+A1) +      ...
                (j>2)*((-1)^j*A1);
nep.M0solver=@(x) nep.MMeval(0)\x;
nep.err=@(lambda,v) norm(nep.MMeval(lambda)*v);
nep.n=n;


v=zeros(n,1);   v(1)=1;
m=100;
[ V, H ] = InfArn( nep, v, m ); V=V(1:n,:);
[ err, conv_eig_IAR ] = iar_error_hist( nep, V, H, '-k' );


N=10;
x=rand(n,N);
y=rand(n,N+1);

y0test=compute_y0(x,y);
y0test

% matrix needed to the expansion
L=@(k)diag([2, 1./(2:k)])+diag(-1./(1:(k-2)),-2);
L(5)

% function for compuing y0 for this specific DEP
function y0=compute_y0(x,y)
    a=1;
    tt=1;
    
    global A0 A1
    T=@(n,x) chebyshevT(n,x);   % Chebyshev polynomials of the first kind
    U=@(n,x) chebyshevU(n,x);   % Chebyshev polynomials of the second kind
    
    n=length(A0);
    N=size(x,2);
    
    y0=zeros(n,1);
    for i=1:N-1
        y0=y0+(2*i/a)*U(i-1,1)*x(:,i+1);
    end
    
    for i=1:N
        y0=y0+(-A0)*y(:,i+1);
    end
    
    for i=1:N
        y0=y0+(-A1)*T(i,1+2*tt/a)*y(:,i+1);
    end
    y0=(A0+A1)\y0;
    
end


