// (1) Extraction du nom de fichier et création des dossiers si inexistants
rawID = getImageID();
title = getTitle();
dir = getDirectory("image");

dotIndex = lastIndexOf(title, ".");
if (dotIndex != -1) {
    baseName = substring(title, 0, dotIndex);
} else {
    baseName = title;
}

csvPath = dir + "Resultats_Analyse4_GUS.csv";
dirLeaf = dir + "MB4-Feuille" + File.separator;
dirGUS  = dir + "MB4-GUS" + File.separator;

if (!File.exists(dirLeaf)) File.makeDirectory(dirLeaf);
if (!File.exists(dirGUS))  File.makeDirectory(dirGUS);

run("Set Measurements...", "area mean standard min max median integrated limit redirect=None decimal=3");

// (2) Mesure de la surface de la feuille
selectImage(rawID);
// run("Line to Area"); // Seulement pour les tracés de veines
run("Duplicate...", " ");
leafImageID = getImageID();

run("ROI Manager...");
roiManager("Reset");
roiManager("Add");
roiManager("Select", 0);
roiManager("Rename", "leaf");

run("Create Mask");
saveAs("Tiff", dirLeaf + baseName + "_mask_leaf.tif");

run("Measure");
areaFeuille = getResult("Area", nResults - 1);
close();

// (3) Mesure de la surface du signal GUS
selectImage(rawID);
run("Duplicate...", " ");
gusTempID = getImageID();
run("Split Channels");

blue = nImages;
selectImage(blue);
close();
green = nImages;
selectImage(green);
close();
red = nImages;
selectImage(red);
run("8-bit");

setAutoThreshold("Default no-reset");
setThreshold(0, 85);
run("Convert to Mask");

saveAs("Tiff", dirGUS + baseName + "_mask_GUS.tif");

run("Select None");
run("Analyze Particles...", "add");

n = roiManager("count");

if (n > 1) {
    // Si des particules GUS ont été trouvées (index 1 à n-1)
    allIndices = Array.getSequence(n);
    indices = Array.slice(allIndices, 1); 

    roiManager("Select", indices);
    roiManager("Combine");
    roiManager("Add");
    roiManager("Select", n);
    roiManager("Rename", "GUS_combined");
    GUSIndex = roiManager("count") - 1;
} else {
    // Aucune particule GUS trouvée sous le seuil de 85
    print("Aucun signal GUS détecté sous le seuil pour " + title);
    GUSIndex = -1;
}

// (4) Mesure de l'intensité du signal GUS
selectImage(rawID);
run("Duplicate...", " ");
run("8-bit");
run("Invert");

n = roiManager("count");

leafIndex = -1;
for (i=0; i<n; i++) {
    roiManager("Select", i);
    currentName = Roi.getName(); 
    if (currentName == "leaf") {
        leafIndex = i;
    }
}

if (leafIndex == -1) {
    exit("Erreur : Le ROI nommé 'leaf' n'a pas été trouvé.");
} // Pour être safe seulement

areaGUS = 0;
medianGUS = 0;
stdDevGUS = 0;
maxGUS = 0;
meanGUS = 0;

if (GUSIndex != -1) {
    // Intersecter le limbe et les zones GUS
    roiManager("Select", newArray(leafIndex, GUSIndex));
    roiManager("AND");
    roiManager("Add");

    roiManager("Show None");

    n = roiManager("count");
    roiManager("Select", n-1);
    run("Measure");

    areaGUS = getResult("Area", nResults - 1);
    meanGUS = getResult("Mean", nResults - 1);
    medianGUS = getResult("Median", nResults - 1);
    stdDevGUS = getResult("StdDev", nResults - 1);
    maxGUS = getResult("Max", nResults - 1); 
}

close();
roiManager("Reset");

// (5) Ajout dans le fichier .csv
if (!File.exists(csvPath)) {
    header = "Nom_Image,Area_Feuille,Area_GUS,Median_Intensite_GUS,StdDev_GUS,Max_Intensite_GUS,Mean_Intensite_GUS";
    File.append(header, csvPath);
}

ligneDonnees = baseName + "," + areaFeuille + "," + areaGUS + "," + medianGUS + "," + stdDevGUS + "," + maxGUS + "," + meanGUS;
File.append(ligneDonnees, csvPath);
print("Enregistrement terminé")

//close();