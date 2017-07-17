classdef PaperRaceEnv < handle
    %PAPERRACEENV Paper Race környezet
    %   Osztály, ami környezetet biztosít a paper race játékhoz.
    
    properties
        TrkPic
        Trk
        GGPic
        SzakLis
        lepesek = 0 % az eddig megtett lépések száma
        Szak = 2    % a következõ átszakítandó szakasz száma
        KezdoPoz
    end
    
    methods
        
        function obj = PaperRaceEnv(TrkPic, Trk, GGPic, SzakLis)
            % PAPERRACEENV PaperRaceEnv konstruktor
            %   obj = új PaperRaceEnv objektum
            %   TrkPic: a pálya képe
            %   Trk: a pálya képén a pálya színe
            %   GGPic: a sebességváltoztató képesség diagrammjának képe,
            %           fehér pixel az engedélyezett, fekete a tiltott
            %           változtatás
            %   SzakLis: a szakaszokat tartalmazó, 4 oszlopos mátrix,
            %            elsõ sorában a startvonal, utolsóban a célvonal
            %            oszlopok: xKezdõ, yKezdõ, xVég, yVég
            
            narginchk(4, 4)
            %TODO: bemenet ellenõrzése
            
            if ischar(TrkPic) % Ha elérési utat kaptunk
                TrkPic = imread(TrkPic);
            end
            obj.TrkPic = TrkPic;
            if size(Trk) == 1 % Ha csak szürke intenziátását kaptuk
                Trk = [Trk Trk Trk];
            end
            obj.Trk = reshape(Trk, 1, 3); % Biztos sorvektor legyen
            if ischar(GGPic) % Ha elérési utat kaptunk
                GGPic = imread(GGPic);
            end
            obj.GGPic = GGPic;
            obj.SzakLis = SzakLis;
            start = SzakLis(1, :); %[x1 y1 x2 y2]
            obj.KezdoPoz = [ floor((start(1)+start(3))/2), floor((start(2)+start(4))/2) ];
        end
        
        function drawTrack(obj)
            % DRAWTRACK Kirajzolja a pályát
            
            %Rajzoljuk be a szakaszokat és a pályát: (Amikor az uccsó szakaszt is 
            %"átvágjuk", akkor vége lesz)
            image(obj.TrkPic);
            for i = 1:size(obj.SzakLis,1)
                line( [obj.SzakLis(i,1); obj.SzakLis(i,3)], ...
                      [obj.SzakLis(i,2); obj.SzakLis(i,4)], ...
                      'color','g','Marker','.');
            end
        end
        
        function [SpdNew, PosNew, reward, vege] = lep(obj, SpdChn, SpdOld, PosOld, rajz, szin)
            % LEP Ez a függvény számolja a lépést
            %   Output:
            %   SpdNew: Az új (a lépés utáni) sebességvektor [Vx,Vy]
            %   PosNew: Az új (a lépés utáni) pozíció [Px,Py]
            %   reward: A kapott jutalom
            %   vege: logikai érték, vége ha a vége valamiért az epizódnak
            %   Inputs:
            %   SpdChn: A sebesség megváltoztatása. (De ez relatívban van!!!)
            %   SpdOld: Az aktuális sebességvektor
            
            vege = false;
            reward = 0;
            
            %Az aktuális sebesség irányvektora:
            e1SpdOld = SpdOld/norm(SpdOld);
            e2SpdOld = [-e1SpdOld(2) e1SpdOld(1)];
            %A valtozás a Globálisban:
            SpdChnGlb = round([e1SpdOld' e2SpdOld']*SpdChn');
            %Az új sebességvektor:
            SpdNew = SpdOld + SpdChnGlb';
            PosNew = PosOld + SpdNew;
            
            %TODO: remove, only for debugging
            if(rajz)
                hold on;
                line( [PosOld(1), PosNew(1)], [PosOld(2), PosNew(2)], ...
                          'color',szin,'Marker','.');
            end
                  
            %büntetés, ha kisiklunk
            if(~obj.palyae(PosNew))
                reward = -50;
                vege = true;
            end
            
            %ha megáll az autó, vége a körnek - a 0 sebességet nem
            %tudjuk kezelni, mert a globális gyorsítás számolásához tudnunk
            %kellene a vektor irányát, ami 0 vektornál nem túl lehetséges
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
            %PALYA Ha pálya a Pos, akkor 1-et (true) ad vissza
            %   Trk a pálya színkódja. pl.: [99,99,99]
            %   Pos az aktuális pozíció pl.: [balról jobbra, fentrõl le]
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
            %Ha a Pos-ból húzott Spd vektor metszi a celvonalat (Szakasz(!), 
            %nem egynes) akkor 1-et ad vissza (true)
            %t2 az az ertek ami mgmondja hogy a Spd hanyadánál metszi a celvonalat. Ha
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
            %szakaszokon belulre esik-e: Ha mindket t, t1 es t2 is kisebb mint 1 és
            %nagyobb mint 0
            celba = (0<=t1) && (t1<=1) && (0<=t2) && (t2<=1);
            if not(celba) 
                t2 = 0;
            end
        end
        
        function SpdChange = GGAction(obj, Act)
            %A GG alakja alapán (GGPic) az Action-ként kapott irányhoz hozzárendeli az
            %abba az irányban aktuális legnagyobb hosszt.
            %Act:   A beavatkozás (Action,) most 1-9 szám. Majd át kell írni ha többet
            %akarunk
            %GGPic: Egy kép ami a GGDiagramot tartalmazza. Azt hogy melyik irányba
            %       milyen hosszút lehet változtatni a sebesség vektoron.
            % SpdChange=[x-xsrt, y-ysrt]

            validateattributes(Act, {'numeric'}, {'integer', '>=', 1, '<=', 9})
            if (1 <= Act) && (Act <= 9) 
                %a GGpic 41x41-es B&W bmp. A közepétõl nézzük, meddig fehér. (A közepén,
                %csak hogy látszódjon, van egy fekete pont!
                xsrt = 21; ysrt = 21;
                r = 1;
                PixCol = 1;
                while PixCol
                    %lépjünk az Act irányba +1 pixelnyit, mik x és y ekkor:
                    rad = pi/4*(Act+3);
                    y = ysrt + round(sin(rad)*r);
                    x = xsrt + round(cos(rad)*r);
                    r = r + 1;

                    %Milyen itt a szín. (GG-n belül vagyunk-e még?
                    PixCol = obj.GGPic(x,y);
                end
                SpdChange = [-x+xsrt, y-ysrt];
            else
                %Ha 9 az Action, akkor nem változik semmi
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
            data(5) = inp(5) / sizeGGX; %Az action vektor átlaga 0 körülinek feltételezhetõ, így csak a méretét kell normalizálni
            data(6) = inp(6) / sizeGGY;
        end
        
%         function data = normalize_data(this, inp)
%             data = inp;
%         end
        
    end
    
end

