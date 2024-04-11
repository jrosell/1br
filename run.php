<?php
// https://dev.to/realflowcontrol/processing-one-billion-rows-in-php-3eg0
error_reporting(E_ERROR | E_PARSE);
$start = microtime(true);

$sep = ",";
$stations = [];
//$fp = fopen('measurements.1e6.csv', 'r');
//$fp = fopen('measurements.1e7.csv', 'r');
$fp = fopen('measurements.1e9.csv', 'r');
$first = fgetcsv($fp, null, ',');

while ($data = fgets($fp)) {
    $pos = strpos($data, $sep);
    $temp = (float)substr($data, 0, $pos);
    $city = substr($data, $pos+1, -1);
    $station = &$stations[$city];
    if ($station == NULL) {
        $station = [
            $temp,
            $temp,
            $temp,
            1
        ];
    }
    $station[3] ++;
    $station[2] += $temp;
    if ($temp < $station[0]) {
        $station[0] = $temp;
    }
    elseif ($temp > $station[1]) {
        $station[1] = $temp;
    }
}

ksort($stations);

// echo count($stations); 
// print_r($stations);

echo '{';
foreach($stations as $k=>&$station) {
    $station[2] = $station[2]/$station[3];
    echo $k, '=', $station[0], '/', $station[2], '/', $station[1], ', ';
}
echo '}';

$end = microtime(true);
$time = number_format(($end - $start), 2);
echo "\nEnded in ", $time, " seconds\n";
    
