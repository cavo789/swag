{ AUTEUR            : AVONTURE Christophe
  BUT DE L'UNITE    : FOURNIR LES FONCTIONS DE GESTION DE LA SOURIS

  DATE DE REDACTION : 8 MARS 1996
  DERNIERE MODIF.   : 8 MARS 1996 
}

UNIT uMouse;

INTERFACE

TYPE

   cgCoord = (cgPixel, cgCharacter);

CONST

   { Nombre de Handle actuellement associï¿½ au Handler de la souris }

   cgCurrentProc : Byte = 0;

   { Autorise l'appel aux diffï¿½rentes procï¿½dures crï¿½ï¿½es par les Handler ou
     interdit leur appel. }

   cgEnableMouseProc : Boolean = True;

   { Dï¿½finit si les coordonnï¿½es sont ï¿½ considï¿½rer comme ï¿½tant relatifs ï¿½ des
     pixels ou bien relatifs ï¿½ des caractï¿½res }

   cgCoordonnees : cgCoord = cgPixel;

TYPE

   { Constantes Boutons enfoncï¿½s }

   cgMouse_Key = (cgMouse_None, cgMouse_Left, cgMouse_Right, cgMouse_Both);

   { Structure permettant d'associer une procï¿½dure lorsque le clic de la
     souris se fait dans le rectangle dï¿½limitï¿½ par
           (XMin, YMin) -------------- (XMax, YMin)
                :                            :
                :                            :
           (XMin, YMax) -------------- (XMax, YMax) }

   TProcedure = PROCEDURE;

   TMouseHandle = RECORD
      XMin, XMax, YMin, YMax : Word;
      Adress_Proc            : TProcedure;
   END;

   { Lorsque l'utilisateur clic en un certain endroit, si cet endroit est
     compris dans le rectangle spï¿½cifiï¿½ ci-dessus, alors il faudra exï¿½cuter
     une certaine procï¿½dure.

     On va pouvoir spï¿½cifier autant de surfaces diffï¿½rentes. La seule
     restriction sera la mï¿½moire disponible.

     Ainsi, on pourra dessiner un bouton OK, un bouton CLOSE, ... et leur
     associer un ï¿½vï¿½nement qui leur est propre.

     Cela sera obtenu par la gestion d'un liste chaï¿½nï¿½e vers le haut. }

   TpListMouseHandle = ^TListMouseHandle;
   TListMouseHandle  = RECORD
      Next : TpListMouseHandle;
      Item     : TMouseHandle;
   END;

VAR

   { Liste chaï¿½nï¿½e des diffï¿½rents handles associï¿½s au handler de la souris }

   MouseProc      : TpListMouseHandle;  { Zone de travail }
   MouseProcFirst : TpListMouseHandle;  { Tout premier ï¿½vï¿½nement }
   MouseProcOld   : TpListMouseHandle;  { Sauvegarde de l'ancien ï¿½vï¿½nement }

   { True si un gestionnaire de souris est prï¿½sent }

   bMouse_Exist : Boolean;

   { Coordonnï¿½es du pointeur de la souris }

   cgMouse_X    : Word;
   cgMouse_Y    : Word;

   { Correspondant du LastKey.  Contient la valeur du dernier bouton
     enfoncï¿½ }

   cgMouse_LastButton : cgMouse_Key;

   { Lorsque le clic ne se fait pas dans une des surfaces couvertes par les
     diffï¿½rents handlers (voir AddMouseHandler); on peut exï¿½cuter une
     certaine procï¿½dure. }

   hClicNotInArea     : Pointer;

PROCEDURE Mouse_Show;
PROCEDURE Mouse_Hide;
PROCEDURE Mouse_GoToXy (X, Y : Word);
PROCEDURE Mouse_Window (XMin, XMax, YMin, YMax : Word);
PROCEDURE Mouse_AddHandler (XMin, XMax, YMin, YMax : Word; Adress : TProcedure);
PROCEDURE Mouse_RemoveHandler;
PROCEDURE Mouse_Handle;
PROCEDURE Mouse_Flush;

FUNCTION  Mouse_Init    : Boolean;
FUNCTION  Mouse_Pressed : cgMouse_Key;
FUNCTION  Mouse_InArea (XMin, XMax, YMin, YMax : Word) : Boolean;
FUNCTION  Mouse_ReleaseButton (Button : cgMouse_Key) : Boolean;

{ ------------------------------------------------------------------------ }

IMPLEMENTATION

{ Teste si un gestionnaire de souris est prï¿½sent }

FUNCTION Mouse_Init : Boolean;

BEGIN

   ASM

      Xor  Ax, Ax
      Int  33h

      Mov  Byte Ptr bMouse_Exist, Ah

   END;

END;

{ Cache le pointeur de la souris }

PROCEDURE Mouse_Hide; ASSEMBLER;

ASM

    Mov  Ax, 02h
    Int  33h

END;

{ Montre le pointeur de la souris }

PROCEDURE Mouse_Show; ASSEMBLER;

ASM

    Mov  Ax, 01h
    Int  33h

END;

{ Retourne une des constantes ï¿½quivalents aux boutons enfoncï¿½s.  Retourne 0
  si aucun bouton n'a ï¿½tï¿½ enfoncï¿½ }

FUNCTION Mouse_Pressed : cgMouse_Key;  ASSEMBLER;

ASM

    Mov  Ax, 03h
    Int  33h

    { Bx contiendra 0 si aucun bouton n'a ï¿½tï¿½ enfoncï¿½
                    1          bouton de gauche
                    2          bouton de droite
                    3          bouton de gauche et bouton de droite
                    4          bouton du milieu }

    Mov  Ax, Bx
    Mov  cgMouse_X, Cx
    Mov  cgMouse_Y, Dx
    Mov  cgMouse_LastButton, Al

END;

{ Positionne le curseur de la souris }

PROCEDURE Mouse_GoToXy (X, Y : Word); ASSEMBLER;

ASM

    Mov  Ax, 04h
    Mov  Cx, X
    Mov  Dx, Y
    Int  33h

END;

{ Dï¿½finit la fenï¿½tre dans laquelle le curseur de la souris peut ï¿½voluer }

PROCEDURE Mouse_Window (XMin, XMax, YMin, YMax : Word); ASSEMBLER;

ASM

    Mov  Ax, 07h
    Mov  Cx, XMin
    Mov  Dx, XMax
    Int  33h

    Mov  Ax, 08h
    Mov  Cx, YMin
    Mov  Dx, YMax
    Int  33h

END;

{ Teste si le curseur de la souris se trouve dans une certaine surface }

FUNCTION  Mouse_InArea (XMin, XMax, YMin, YMax : Word) : Boolean;

BEGIN

    IF NOT bMouse_Exist THEN 
       Mouse_InArea := False
    ELSE
       BEGIN

          { Les coordonnï¿½es sont-elles ï¿½ considï¿½rer comme pixels ou comme
            caractï¿½res }

          IF cgCoordonnees = cgPixel THEN
             BEGIN

                IF NOT (cgMouse_X < XMin) AND NOT (cgMouse_X > XMax) AND
                   NOT (cgMouse_Y < YMin) AND NOT (cgmouse_y > YMax) THEN
                    Mouse_InArea := True
                ELSE
                    Mouse_InArea := False

             END
          ELSE
             BEGIN

                { Il s'agit de caractï¿½res.  Or un caractï¿½re fait 8 pixels de long.
                  Donc, lorsque l'on programme (0,1,0,1, xxx), il s'agit du
                  caractï¿½re se trouvant en (0,0) qui se trouve en rï¿½alitï¿½ en
                  0..7,0..15 puisqu'il fait 8 pixels de long sur 16 de haut. }

                IF NOT (cgMouse_X Shr 3 < XMin ) AND
                   NOT (cgMouse_X Shr 3 > XMax ) AND
                   NOT (cgMouse_Y Shr 3 < YMin ) AND
                   NOT (cgmouse_y Shr 3 > YMax ) THEN
                     Mouse_InArea := True
                  ELSE
                     Mouse_InArea := False;
               END;
       END;

END;

{ Ajoute un ï¿½vï¿½nement. }

PROCEDURE Mouse_AddHandler (XMin, XMax, YMin, YMax : Word; Adress : TProcedure);

BEGIN

    IF bMouse_Exist THEN
       BEGIN

          { On peut ajouter un ï¿½vï¿½nement pour autant qu'il reste de la mï¿½moire
            disponible pour le stockage du pointeur sur la procï¿½dure et de la
            sauvegarde des coordonnï¿½es de la surface dï¿½limitï¿½e pour son action. }

          IF MemAvail > SizeOf(TListMouseHandle) THEN
             BEGIN

                Inc (cgCurrentProc);

                IF cgCurrentProc = 1 THEN
                   BEGIN

                      { C'est le tout premier ï¿½vï¿½nement.  Sauvegarde du pointeur
                        pour pouvoir ensuite fabriquer la liste. }

                      New (MouseProc);
                      MouseProcFirst := MouseProc;

                      { Sauvegarde du pointeur courant pour pouvoir fabriquer la
                        liste. }

                      MouseProcOld   := MouseProc;

                      { Etant donnï¿½ que le liste se rempli de bas en haut -le
                        premier introduit est le moins prioritaire, ...-; seul le
                        premier aura un pointeur vers NIL.  Cette mï¿½thode permettra
                        ï¿½ un ï¿½vï¿½nement de recouvrir une surface dï¿½jï¿½ dï¿½limitï¿½e par
                        un autre objet. }

                      MouseProc^.Next := NIL;
                   END
                ELSE
                   BEGIN

                      { Ce n'est pas le premier.  Il faut que je crï¿½e le lien avec
                        le pointeur NEXT de l'ï¿½vï¿½nement prï¿½cï¿½dent. }

                      MouseProcOld := MouseProc;
                      New (MouseProc);
                      MouseProc^.Next := MouseProcOld;
                      MouseProcFirst := MouseProc;
                   END;

                { Les liens crï¿½ï¿½s, je peux en toute sï¿½curitï¿½ sauvegarder les
                  donnï¿½es. }

                MouseProc^.Item.XMin    := XMin;
                MouseProc^.Item.XMax    := XMax;
                MouseProc^.Item.YMin    := YMin;
                MouseProc^.Item.YMax    := YMax;
                MouseProc^.Item.Adress_Proc := Adress;

             END;
       END;
END;

{ Cette procï¿½dure retire le tout dernier ï¿½vï¿½nement introduit tout en
  conservant la cohï¿½rence de la liste. }

PROCEDURE Mouse_RemoveHandler;

BEGIN

    IF bMouse_Exist THEN
       BEGIN

          IF NOT (MouseProc^.Next = NIL) THEN
             BEGIN

               MouseProcFirst := MouseProc^.Next;
               Dispose (MouseProc);
               MouseProc := MouseProcFirst;
               Dec (cgCurrentProc);

             END;
       END;

END;


{ Examine si le clic s'est fait dans une surface dï¿½limitï¿½e par un ï¿½vï¿½nement.

  Si c'est le cas, alors appel de l'ï¿½vï¿½nement en question. }

PROCEDURE Mouse_Handle;

VAR
   bFin : Boolean;
   bNotFound : Boolean;

BEGIN

    IF bMouse_Exist THEN
       BEGIN

          { Il doit y avoir un process uniquement si on a associï¿½ des ï¿½lï¿½ments au
            handler de la souris.  ET SEULEMENT SI LES APPELS AUX DIFFERENTES
            PROCEDURES SONT AUTORISES OU NON. }

          IF cgEnableMouseProc AND (cgCurrentProc > 0) THEN
             BEGIN

                bFin := False;

                { bNotFound sera mis sur True lorsque le clic s'est fait dans une
                  surface non couverte par un handler. }

                bNotFound := False;

                { Pointe sur le tout premier ï¿½vï¿½nement }

                MouseProcOld := MouseProcFirst;

                REPEAT

                   IF Mouse_InArea (MouseProcOld^.Item.XMin, MouseProcOld^.Item.XMax,
                      MouseProcOld^.Item.YMin, MouseProcOld^.Item.YMax) THEN
                      BEGIN

                         { Le clic s'est fait dans une surface ï¿½ surveiller.  Appel
                           de l'ï¿½vï¿½nement ad'hoc. }

                         MouseProcOld^.Item.Adress_Proc;
                         bFin := True;
                      END
                   ELSE
                      IF (MouseProcOld^.Next = NIL) THEN
                         BEGIN
                            bNotFound := True;
                            bFin := True
                         END
                      ELSE
                         MouseProcOld := MouseProcOld^.Next;

                UNTIL bFin;

       {         IF bNotFound THEN
                   ASM
                      Call hClicNotInArea;
                   END;}

             END;
       END;
END;

{ Retourne TRUE lorsque l'utilisateur maintien le bouton xxx enfoncï¿½ et
  renvoi FALSE lorsque ce bouton est relï¿½chï¿½. }

FUNCTION Mouse_ReleaseButton (Button : cgMouse_Key) : Boolean; ASSEMBLER;

ASM
   Mov  Ax, 06h
   Mov  Bx, 01h
   Int  33h
END;

{ Cette procï¿½dure va attendre jusqu'ï¿½ ce que le dernier bouton enfoncï¿½ ne
  le soit plus; autrement dit jusqu'ï¿½ ce que l'utilisateur relï¿½che ce mï¿½me
  bouton.  Ce qui aura pour effet de vider le buffer de la souris. }

PROCEDURE Mouse_Flush;

BEGIN


    IF bMouse_Exist THEN
       REPEAT
       UNTIL NOT (Mouse_ReleaseButton(cgMouse_LastButton));

END;

{ Initialisation }

BEGIN

   { Initialise le boolean d'existence d'un gestionnaire de souris }

   Mouse_Init;

   { Positionne le curseur de la souris en (0,0) }

   Mouse_GotoXy (0,0);

END.
