const express = require('express');
const router = express.Router();

const consignorsRoutes = require('./consignors');
const consigneesRoutes = require('./consignees');
const vehiclesRoutes = require('./vehicles');
const driversRoutes = require('./drivers');
const companiesRoutes = require('./companies');
const unitsRoutes = require('./units');
const hsnRoutes = require('./hsn');
const godownsRoutes = require('./godowns');

router.use('/consignors', consignorsRoutes);
router.use('/consignees', consigneesRoutes);
router.use('/vehicles', vehiclesRoutes);
router.use('/drivers', driversRoutes);
router.use('/companies', companiesRoutes);
router.use('/units', unitsRoutes);
router.use('/hsn', hsnRoutes);
router.use('/godowns', godownsRoutes);

module.exports = router;
