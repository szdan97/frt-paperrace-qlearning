classdef PaperRaceEnv < handle
    %PAPERRACEENV Paper Race k�rnyezet
    %   Oszt�ly, ami k�rnyezetet biztos�t a paper race j�t�khoz.
    
    properties
        TrkPic
        Trk
        GGPic
        SzakLis
        lepesek = 0 % az eddig megtett l�p�sek sz�ma
        Szak = 2    % a k�vetkez� �tszak�tand� szakasz sz�ma
        KezdoPoz
    end
    
    methods
        
        function obj = PaperRaceEnv(TrkPic, Trk, GGPic, SzakLis)
            % PAPERRACEENV PaperRaceEnv konstruktor
            %   obj = �j PaperRaceEnv objektum
            %   TrkPic: a p�lya k�pe
            %   Trk: a p�lya k�p�n a p�lya sz�ne
            %   GGPic: a sebess�gv�ltoztat� k�pess�g diagrammj�nak k�pe,
            %           feh�r pixel az enged�lyezett, fekete a tiltott
            %           v�ltoztat�s
            %   SzakLis: a szakaszokat tartalmaz�, 4 oszlopos m�trix,
            %            els� sor�ban a startvonal, utols�ban a c�lvonal
            %            oszlopok: xKezd�, yKezd�, xV�g, yV�g
            
            narginchk(4, 4)
            %TODO: bemenet ellen�rz�se
            
            if ischar(TrkPic) % Ha el�r�si utat kaptunk
                TrkPic = imread(TrkPic);
            end
            obj.TrkPic = TrkPic;
            if size(Trk) == 1 % Ha csak sz�rke intenzi�t�s�t kaptuk
                Trk = [Trk Trk Trk];
            end
            obj.Trk = reshape(Trk, 1, 3); % Biztos sorvektor legyen
            if ischar(GGPic) % Ha el�r�si utat kaptunk
                GGPic = imread(GGPic);
            end
            obj.GGPic = GGPic;
            obj.SzakLis = SzakLis;
            start = SzakLis(1, :); %[x1 y1 x2 y2]
            obj.KezdoPoz = [ floor((start(1)+start(3))/2), floor((start(2)+start(4))/2) ];
        end
        
        function drawTrack(obj)
            % DRAWTRACK Kirajzolja a p�ly�t
            
            %Rajzoljuk be a szakaszokat �s a p�ly�t: (Amikor az uccs� szakaszt is 
            %"�tv�gjuk", akkor v�ge lesz)
            image(obj.TrkPic);
            for i = 1:size(obj.SzakLis,1)
                line( [obj.SzakLis(i,1); obj.SzakLis(i,3)], ...
                      [obj.SzakLis(i,2); obj.SzakLis(i,4)], ...
                      'color','g','Marker','.');
            end
        end
        
        function [SpdNew, PosNew, reward, vege] = lep(obj, SpdChn, SpdOld, PosOld, rajz, szin)
            % LEP Ez a f�ggv�ny sz�molja a l�p�st
            %   Output:
            %   SpdNew: Az �j (a l�p�s ut�ni) sebess�gvektor [Vx,Vy]
            %   PosNew: Az �j (a l�p�s ut�ni) poz�ci� [Px,Py]
            %   reward: A kapott jutalom
            %   vege: logikai �rt�k, v�ge ha a v�ge valami�rt az epiz�dnak
            %   Inputs:
            %   SpdChn: A sebess�g megv�ltoztat�sa. (De ez relat�vban van!!!)
            %   SpdOld: Az aktu�lis sebess�gvektor
            
            vege = false;
            reward = 0;
            
            %Az aktu�lis sebess�g ir�nyvektora:
            e1SpdOld = SpdOld/norm(SpdOld);
            e2SpdOld = [-e1SpdOld(2) e1SpdOld(1)];
            %A valtoz�s a Glob�lisban:
            SpdChnGlb = round([e1SpdOld' e2SpdOld']*SpdChn');
            %Az �j sebess�gvektor:
            SpdNew = SpdOld + SpdChnGlb';
            PosNew = PosOld + SpdNew;
            
            %TODO: remove, only for debugging
            if(rajz)
                hold on;
                line( [PosOld(1), PosNew(1)], [PosOld(2), PosNew(2)], ...
                          'color',szin,'Marker','.');
            end
                  
            %b�ntet�s, ha kisiklunk
            if(~obj.palyae(PosNew))
                reward = -50;
                vege = true;
            end
            
            %ha meg�ll az aut�, v�ge a k�rnek - a 0 sebess�get nem
            %tudjuk kezelni, mert a glob�lis gyors�t�s sz�mol�s�hoz tudnunk
            %kellene a vektor ir�ny�t, ami 0 vektorn�l nem t�l lehets�ges
            if(isequal(SpdNew, [0 0]))
                vege = true;
            end
            
            if(obj.celbaer(PosOld, SpdNew, ...
                    obj.SzakLis(obj.Szak, 1:2), obj.SzakLis(obj.Szak, 3:4)))
                reward = 100;
                obj.Szak = obj.Szak + 1;
                if(obj.Szak > size(obj.SzakLis, 1))
                    vege = true;
                end
            end
        end
        
        function palya = palyae(obj, Pos)
            %PALYA Ha p�lya a Pos, akkor 1-et (true) ad vissza
            %   Trk a p�lya sz�nk�dja. pl.: [99,99,99]
            %   Pos az aktu�lis poz�ci� pl.: [balr�l jobbra, fentr�l le]
            if Pos(1) > size(obj.TrkPic, 2) || Pos(2) > size(obj.TrkPic, 1) || ...
                    Pos(1) < 1 || Pos(2) < 1 || ...
                    isnan(Pos(1)) || isnan(Pos(2)) || Pos(1)<0 || Pos(2)<0
                palya = false;
            else
                if isequal(reshape(obj.TrkPic(Pos(2),Pos(1),:), 1,3), obj.Trk)
                    palya = true; 
                else
                    palya = false; 
                end
            end
        end
        
        function celba = celbaer(this, Pos,Spd,CelBal,CelJob)
            %Ha a Pos-b�l h�zott Spd vektor metszi a celvonalat (Szakasz(!), 
            %nem egynes) akkor 1-et ad vissza (true)
            %t2 az az ertek ami mgmondja hogy a Spd hanyad�n�l metszi a celvonalat. Ha
            %t2=1 akkor a Spd vektor eppenhogy eleri a celvonalat.
            % CelBal = [250,60];
            % CelJob = [250,100];
            % Spd = [20, 0];
            % Pos = [240, 80];

            %keplethez kello ertekek. p1, es p2 pontokkal valamint v1 es v2
            %iranyvektorokkal adott egyenesek metszespontjat nezzuk, ugy hogy a
            %celvonal egyik pontjabol a masikba mutat a v1, a v2 pedig a sebesseg, p2
            %pedig a pozicio
            v1y=CelJob(1) - CelBal(1);
            v1z=CelJob(2) - CelBal(2);
            v2y=Spd(1);
            v2z=Spd(2);

            p1y=CelBal(1);
            p1z=CelBal(2);
            p2y=Pos(1);
            p2z=Pos(2);

            %t2 azt mondja hogy a p1 pontbol v1 iranyba indulva v1 hosszanak hanyadat
            %kell megtenni hogy elerjunk a metszespontig. Ha t2=1 epp v2vegpontjanal
            %van a metszespopnt. t1,ugyanez csak p1 es v2-vel.
            t2 = (-v1y*p1z+v1y*p2z+v1z*p1y-v1z*p2y)/(-v1y*v2z+v1z*v2y);
            t1 = (p1y*v2z-p2y*v2z-v2y*p1z+v2y*p2z)/(-v1y*v2z+v1z*v2y);

            %Annak eldontese hogy akkor az egyenesek metszespontja az most a
            %szakaszokon belulre esik-e: Ha mindket t, t1 es t2 is kisebb mint 1 �s
            %nagyobb mint 0
            celba = (0<=t1) && (t1<=1) && (0<=t2) && (t2<=1);
            if not(celba) 
                t2 = 0;
            end
        end
        
        function SpdChange = GGAction(obj, Act)
            %A GG alakja alap�n (GGPic) az Action-k�nt kapott ir�nyhoz hozz�rendeli az
            %abba az ir�nyban aktu�lis legnagyobb hosszt.
            %Act:   A beavatkoz�s (Action,) most 1-9 sz�m. Majd �t kell �rni ha t�bbet
            %akarunk
            %GGPic: Egy k�p ami a GGDiagramot tartalmazza. Azt hogy melyik ir�nyba
            %       milyen hossz�t lehet v�ltoztatni a sebess�g vektoron.
            % SpdChange=[x-xsrt, y-ysrt]

            validateattributes(Act, {'numeric'}, {'integer', '>=', 1, '<=', 9})
            if (1 <= Act) && (Act <= 9) 
                %a GGpic 41x41-es B&W bmp. A k�zep�t�l n�zz�k, meddig feh�r. (A k�zep�n,
                %csak hogy l�tsz�djon, van egy fekete pont!
                xsrt = 21; ysrt = 21;
                r = 1;
                PixCol = 1;
                while PixCol
                    %l�pj�nk az Act ir�nyba +1 pixelnyit, mik x �s y ekkor:
                    rad = pi/4*(Act+3);
                    y = ysrt + round(sin(rad)*r);
                    x = xsrt + round(cos(rad)*r);
                    r = r + 1;

                    %Milyen itt a sz�n. (GG-n bel�l vagyunk-e m�g?
                    PixCol = obj.GGPic(x,y);
                end
                SpdChange = [-x+xsrt, y-ysrt];
            else
                %Ha 9 az Action, akkor nem v�ltozik semmi
                SpdChange = [0, 0, 0, 0];
            end
        end
        
        function reset(obj)
            obj.Szak = 2;
        end
        
        function data = normalize_data(this, inp)
            data = zeros(1, 6);
            sizeX = size(this.TrkPic, 2);
            sizeY = size(this.TrkPic, 1);
            data([1 3]) = (inp([1 3]) - sizeX/2) / sizeX;
            data([2 4]) = (inp([2 4]) - sizeY/2) / sizeY;
            sizeGGX = size(this.GGPic, 2);
            sizeGGY = size(this.GGPic, 1);
            data(5) = inp(5) / sizeGGX; %Az action vektor �tlaga 0 k�r�linek felt�telezhet�, �gy csak a m�ret�t kell normaliz�lni
            data(6) = inp(6) / sizeGGY;
        end
        
%         function data = normalize_data(this, inp)
%             data = inp;
%         end
        
    end
    
end

