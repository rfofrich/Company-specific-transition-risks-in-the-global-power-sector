%Asset value
%
%Created Aug 14 2024
%by Robert Fofrich Navarro
%
%Calculates corporate asset value and assigns values to power plant parent company
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
FUEL = 1;% sets fuel %1 COAL,2 GAS, 3 OIL, 4 Combined
clearvars -except ii; close all

TJ_to_BTu = 1/(9.478*1e8);
Kg_CO2_to_t_C02 = 1/1000;
BTu_perKWh_to_BTu_perMWh = 1000;

max_marker_size = 3000;
min_marker_size = 200; 


PowerPlantFuel = ["Coal", "Gas", "Oil"];
saveyear = 0;%saves decommission year; any other number loads decommission year
saveresults = 1;
randomsave = 1;%set to 1 to save MC randomization; zero value  loads MC randomization - section 11 only

%works with section 6
COUNTRY = 1; %1 United States, 3 china, 4 europe, 9 india


if FUEL <4
    CombineFuelTypeResults = 0;
elseif FUEL >3
    CombineFuelTypeResults = 1;
end

current_year = 2024;
cutoffyear = 2035;%follows the index for carbontaxyear vector
CarbonPrice = 2000;%$/tCO2
CarbonTaxYear = current_year:2100;%sets the year for which the carbon tax is at its maximum

[ Dateindx] = find(CarbonTaxYear == cutoffyear);

StartYear = 1900;
EndYear = current_year;
Year = StartYear:EndYear;

RetailtoWholesaleConversionFactor = 1;%assumption

%Median PowerPlant Costs and Life from IPCC AR5 WGIII
%(https://www.ipcc.ch/site/assets/uploads/2018/02/ipcc_wg3_ar5_annex-iii.pdf)
%Power plant life
 
interest_rate_construction = .05; % interest rate over the construction loan (set as 5%)
DiscountRate = .1; %rate used by IEA 2020 report, 7% is in a highly regulated market, and 10% is in an environment with high risks

mean_Life_coal = 40;
Variable_OM_coal = 3.4;% $/MWh
Fixed_OM_coal = 23*1000;% $/MW
Construction_period_coal = 6; 
Capital_costs_coal = 2200*1000;% $/MW
Fuel_costs_coal = 4.1/3.6; % $/MWh
alpha_coal = DiscountRate/(1-(1+DiscountRate).^-mean_Life_coal);% percent
eta_coal = .39;% percent
Investment_costs_coal = (Capital_costs_coal/mean_Life_coal)*sum((1+interest_rate_construction)*(1+(0/(1+DiscountRate).^mean_Life_coal)));

mean_Life_gas = 30;
Variable_OM_gas = 3.2;% $/MWh
Fixed_OM_gas = 7*1000;% $/MW
Construction_period_gas = 4; 
Capital_costs_gas = 1100*1000;% $/MW
Fuel_costs_gas = 8.9*3.6; % $/MWh
alpha_gas = DiscountRate/(1-(1+DiscountRate).^-mean_Life_gas);% percent
eta_gas = .55;% percent
Investment_costs_gas = (Capital_costs_gas/mean_Life_gas)*sum((1+interest_rate_construction)*(1+(0/(1+DiscountRate).^mean_Life_gas)));

%Power plant ranges
LifeTimeRange = 20:5:60; 
CapacityFactorRange = .25:.05:.75;
AnnualHours = 8760;

%plus/minus age
Age_span = 20;% Power plant age range

%plus/minus CF
CF_span = .25;% Power plant capacity factor range
if FUEL == 1
    years = 2021:(current_year + mean_Life_coal);
elseif FUEL == 2
    years = 2021:(current_year + mean_Life_gas);
end

        
for gentype = FUEL
    load(['../Data/Results/' PowerPlantFuel{gentype} '_Plants']);
    load(['../Data/Results/' PowerPlantFuel{gentype} '_Plants_strings']);
    load(['../Data/Results/' PowerPlantFuel{gentype} 'CostbyCountry'])
    load(['../Data/WholeSaleCostofElectricity' PowerPlantFuel{gentype} '']);
    CarbonTax19 = xlsread('../Data/CarbonTax1_9.xlsx','standard');
    CarbonTax26 = xlsread('../Data/CarbonTax2_6.xlsx','standard');
    load(['../Data/Results/' PowerPlantFuel{gentype} 'Colors'])
    if gentype == 1
        colorschemecategoryFuel = colorschemecategoryCoal;
    else
        colorschemecategoryFuel = colorschemecategoryGas;
    end
    Plants(isnan(Plants)) = 0;
    
    clear PowerPlantProfits

    PowerPlantRevenue = zeros(length(Plants),1);

    for generator = 1:length(Plants)
        PowerPlantRevenue(generator,1) = (Plants(generator,1).*Plants(generator,3).*AnnualHours.*WholeSaleCostofElectricity(generator,1)*RetailtoWholesaleConversionFactor);
    end
    
    FuelCosts = F_Costs;

    if gentype == 1
        LifeLeft = mean_Life_coal - Plants(:,2);
        mean_Life = mean_Life_coal;
    elseif gentype == 2
        LifeLeft = mean_Life_gas - Plants(:,2);
        mean_Life = mean_Life_gas;
    end

    if saveyear == 1
        for generator = 1:length(Plants)
            if isnan(Planned_decommission(generator))
                if LifeLeft(generator,1) <=0 
                    yearsleft = randi(5);
                    DecommissionYear(generator,1) = current_year + yearsleft;
                    LifeLeft(generator,1) = yearsleft;
                elseif LifeLeft(generator,1) > 0
                    DecommissionYear(generator,1) = current_year + LifeLeft(generator,1);
                    LifeLeft(generator,1) = LifeLeft(generator,1);
                end
            elseif ~isnan(Planned_decommission(generator))
                   LifeLeft(generator,1) = Planned_decommission(generator) - current_year;

                if LifeLeft(generator,1) <=0 
                    yearsleft = randi(5);
                    DecommissionYear(generator,1) = current_year + yearsleft;
                    LifeLeft(generator,1) = yearsleft;

                elseif LifeLeft(generator,1) > 0
                    DecommissionYear(generator,1) = current_year + LifeLeft(generator,1);
                    LifeLeft(generator,1) = LifeLeft(generator,1);
                end
            end
        end
        DecommissionYear(28522:28525) = 0; % not iterating through the final power plants due to nans, these are decomissioned anyways
        save(['../Data/Results/DecommissionYear' PowerPlantFuel{gentype} ''],'DecommissionYear','LifeLeft');
    elseif saveyear ~=1
        load(['../Data/Results/DecommissionYear' PowerPlantFuel{gentype} ''])
    end

    max_Life = nanmax(LifeLeft);

    LifeLeft(isnan(LifeLeft))=0;

    if gentype == 1 


        for generator = 1:length(Plants)
            OM_costs(generator) = Fixed_OM_coal*Plants(generator,1) + Variable_OM_coal*Plants(generator,1).*Plants(generator,3).*AnnualHours;
        end

        for generator = 1:length(Plants)
            Cost_of_Fuel(generator) = Fuel_costs_coal*((Plants(generator,1).*Plants(generator,3).*AnnualHours)/eta_coal);
        end

        for generator = 1:length(Plants)
            Costs(generator) = (alpha_coal*Investment_costs_coal+OM_costs(generator)+Cost_of_Fuel(generator));
        end

        Costs = Costs';
        Costs(PowerPlantRevenue==0)=0;

        Costs(Costs == Inf)=nan;
        Costs(Costs == 0)=nan;

    
        for generator = 1:length(Plants)
            PowerPlantProfits(generator,1:LifeLeft(generator,1)) = PowerPlantRevenue(generator) - Costs(generator);
        
            PowerPlant_StringInformation(generator,1) = Plants_string(generator,1);%corporate owner of the plant
            PowerPlant_StringInformation(generator,2) = Plants_string(generator,2);%national location of the plant
            PowerPlant_StringInformation(generator,3) = Plants_string(generator,3);%Operating status
        end

        PowerPlantProfits_CarbonTax = zeros(length(PowerPlantProfits),max_Life,4);
        Stranded_Assets_based_on_added_costs = zeros(size(PowerPlantProfits_CarbonTax));
        for generator = 1:length(Plants)%%add in carbon tax portion
            for tax = 1:4%1 - global carbon tax 1.9, 2 - region specific 1.9, 3 - global carbon tax 2.6, 4 - region specific 2.6
                for yr = 1:max_Life
                    if tax == 1
                        PowerPlantProfits_CarbonTax(generator,yr,tax) = PowerPlantRevenue(generator) - Costs(generator) - CarbonTax19(yr+4,7)*(Plants(generator,1).*Plants(generator,3).*AnnualHours.*(Heat_rate(generator))*(Emission_factor(generator)*TJ_to_BTu*Kg_CO2_to_t_C02)) * (Plants(generator,5)/100); %starts carbon tax at the year 2024
                        Stranded_Assets_based_on_added_costs(generator,yr,tax) = CarbonTax19(yr+4,7)*(Plants(generator,1).*Plants(generator,3).*AnnualHours.*(Heat_rate(generator))*(Emission_factor(generator)*TJ_to_BTu*Kg_CO2_to_t_C02)) * (Plants(generator,5)/100); 
                    elseif tax == 2
                        PowerPlantProfits_CarbonTax(generator,yr,tax) = PowerPlantRevenue(generator) - Costs(generator) - CarbonTax19(yr+4,Plants(generator,12)+1)*(Plants(generator,1).*Plants(generator,3).*AnnualHours.*(Heat_rate(generator))*(Emission_factor(generator)*TJ_to_BTu*Kg_CO2_to_t_C02)) * (Plants(generator,5)/100); %starts carbon tax at the year 2024
                        Stranded_Assets_based_on_added_costs(generator,yr,tax) = CarbonTax19(yr+4,Plants(generator,12)+1)*(Plants(generator,1).*Plants(generator,3).*AnnualHours.*(Heat_rate(generator))*(Emission_factor(generator)*TJ_to_BTu*Kg_CO2_to_t_C02)) * (Plants(generator,5)/100); 
                    elseif tax == 3
                        PowerPlantProfits_CarbonTax(generator,yr,tax) = PowerPlantRevenue(generator) - Costs(generator) - CarbonTax26(yr+4,7)*(Plants(generator,1).*Plants(generator,3).*AnnualHours.*(Heat_rate(generator))*(Emission_factor(generator)*TJ_to_BTu*Kg_CO2_to_t_C02)) * (Plants(generator,5)/100); %starts carbon tax at the year 2024
                        Stranded_Assets_based_on_added_costs(generator,yr,tax) = CarbonTax26(yr+4,7)*(Plants(generator,1).*Plants(generator,3).*AnnualHours.*(Heat_rate(generator))*(Emission_factor(generator)*TJ_to_BTu*Kg_CO2_to_t_C02)) * (Plants(generator,5)/100); 
                    elseif tax == 4
                        PowerPlantProfits_CarbonTax(generator,yr,tax) = PowerPlantRevenue(generator) - Costs(generator) - CarbonTax26(yr+4,Plants(generator,12)+1)*(Plants(generator,1).*Plants(generator,3).*AnnualHours.*(Heat_rate(generator))*(Emission_factor(generator)*TJ_to_BTu*Kg_CO2_to_t_C02)); %starts carbon tax at the year 2024
                        Stranded_Assets_based_on_added_costs(generator,yr,tax) = CarbonTax26(yr+4,Plants(generator,12)+1)*(Plants(generator,1).*Plants(generator,3).*AnnualHours.*(Heat_rate(generator))*(Emission_factor(generator)*TJ_to_BTu*Kg_CO2_to_t_C02)) * (Plants(generator,5)/100); 
                    end
                end
            end
        end

        for i = 1:length(Plants)
            for j = 1:max_Life
                if PowerPlantProfits(i,j) == 0 %ensures power plant profits set to zero if power plant is decommisioned based on operational life
                    PowerPlantProfits_CarbonTax(i,j,:) = 0;
                    Stranded_Assets_based_on_added_costs(i,j,:) = 0;
                end
            end
        end

    elseif gentype ==2 

        for generator = 1:length(Plants)
            OM_costs(generator) = Fixed_OM_gas*Plants(generator,1) + Variable_OM_gas*Plants(generator,1).*Plants(generator,3).*AnnualHours;
        end

        for generator = 1:length(Plants)
            Cost_of_Fuel(generator) = Fuel_costs_gas*((Plants(generator,1).*Plants(generator,3).*AnnualHours)/eta_gas);
        end

        for generator = 1:length(Plants)
            Costs(generator) = (alpha_gas*Investment_costs_gas+OM_costs(generator)+Cost_of_Fuel(generator));
        end

        Costs = Costs';
        Costs(PowerPlantRevenue==0)=0;

        Costs(Costs == Inf)=nan;
        Costs(Costs == 0)=nan;

    
        for generator = 1:length(Plants)
            PowerPlantProfits(generator,1:LifeLeft(generator,1)) = PowerPlantRevenue(generator) - Costs(generator);
        
            PowerPlant_StringInformation(generator,1) = Plants_string(generator,1);%corporate owner of the plant
            PowerPlant_StringInformation(generator,2) = Plants_string(generator,2);%national location of the plant
            PowerPlant_StringInformation(generator,3) = Plants_string(generator,3);%Operating status
        end

        PowerPlantProfits_CarbonTax = zeros(length(PowerPlantProfits),max_Life,4);
        Stranded_Assets_based_on_added_costs = zeros(size(PowerPlantProfits_CarbonTax));
        for generator = 1:length(Plants)%%add in carbon tax portion
            for tax = 1:4%1 - global carbon tax 1.9, 2 - region specific 1.9, 3 - global carbon tax 2.6, 4 - region specific 2.6
                for yr = 1:max_Life
                    if tax == 1
                        PowerPlantProfits_CarbonTax(generator,yr,tax) = PowerPlantRevenue(generator) - Costs(generator) - CarbonTax19(yr+4,7)*Plants(generator,1).*Plants(generator,3).*AnnualHours.*(Emission_factor(generator)) *(Plants(generator,5)/100); %starts carbon tax at the year 2024
                        Stranded_Assets_based_on_added_costs(generator,yr,tax) =CarbonTax19(yr+4,7)*Plants(generator,1).*Plants(generator,3).*AnnualHours.*(Emission_factor(generator))*(Plants(generator,5)/100) ; % equation based on https://www.gem.wiki/Estimating_carbon_dioxide_emissions_from_gas_plants
                    elseif tax == 2
                        PowerPlantProfits_CarbonTax(generator,yr,tax) = PowerPlantRevenue(generator) - Costs(generator) - CarbonTax19(yr+4,Plants(generator,12)+1)*Plants(generator,1).*Plants(generator,3).*AnnualHours.*(Emission_factor(generator)) *(Plants(generator,5)/100); 
                        Stranded_Assets_based_on_added_costs(generator,yr,tax) = CarbonTax19(yr+4,Plants(generator,12)+1)*Plants(generator,1).*Plants(generator,3).*AnnualHours.*(Emission_factor(generator)) *(Plants(generator,5)/100);
                    elseif tax == 3
                        PowerPlantProfits_CarbonTax(generator,yr,tax) = PowerPlantRevenue(generator) - Costs(generator) - CarbonTax26(yr+4,7)*Plants(generator,1).*Plants(generator,3).*AnnualHours.*(Emission_factor(generator))*(Plants(generator,5)/100) ;
                        Stranded_Assets_based_on_added_costs(generator,yr,tax) = CarbonTax26(yr+4,7)*Plants(generator,1).*Plants(generator,3).*AnnualHours.*(Emission_factor(generator)) *(Plants(generator,5)/100); 
                    elseif tax == 4
                        PowerPlantProfits_CarbonTax(generator,yr,tax) = PowerPlantRevenue(generator) - Costs(generator) - CarbonTax26(yr+4,Plants(generator,12)+1)*Plants(generator,1).*Plants(generator,3).*AnnualHours.*(Emission_factor(generator)) *(Plants(generator,5)/100); 
                        Stranded_Assets_based_on_added_costs(generator,yr,tax) = CarbonTax26(yr+4,Plants(generator,12)+1)*Plants(generator,1).*Plants(generator,3).*AnnualHours.*(Emission_factor(generator)) *(Plants(generator,5)/100); 
                    end
                end
            end
        end

        for i = 1:length(Plants)
            for j = 1:max_Life
                if PowerPlantProfits(i,j) == 0 %ensures power plant profits set to zero if power plant is decommisioned based on operational life
                    PowerPlantProfits_CarbonTax(i,j,:) = 0;
                    Stranded_Assets_based_on_added_costs(i,j,:) = 0;
                end
            end
        end


    end
    PowerPlantProfits_CarbonTax(isnan(PowerPlantProfits_CarbonTax)) = 0;
    PowerPlantProfits(isnan(PowerPlantProfits))=0;

    %calculates the proportion of power plant assets by company based
    %on the percent ownership of that company
    for generators = 1:length(Plants)
        PowerPlantProfits(generator,:) = PowerPlantProfits(generator,:) * (Plants(generator,5)/100);
    end

    Present_Value_Stranded_Assets_based_on_added_costs = zeros(size(PowerPlantProfits_CarbonTax));
    for generator = 1:length(Plants)
        for yr = 1:max_Life
            PresentAssetValue(generator,yr) = PowerPlantProfits(generator,yr)./(1 + DiscountRate).^yr;
        end
    end 
             
    for generator = 1:length(Plants)
        for yr = 1:max_Life
            for i = 1:4
                PresentAssetValue_Carbontax(generator,yr,i) = PowerPlantProfits_CarbonTax(generator,yr,i)./((1 + DiscountRate).^yr);
                Present_Value_Stranded_Assets_based_on_added_costs(generator,yr,i) = Stranded_Assets_based_on_added_costs(generator,yr,i)./((1 + DiscountRate).^yr);
            end
        end
    end         

                
    StrandedAssetValue = zeros(size(PowerPlantProfits_CarbonTax));

     for generator = 1:length(Plants) % We only care about the difference of these two values. Stranded assets would be equal to the additional unrecoverable costs added to the power infrastrucutre regardless of profits
        for yr = 1:max_Life
            for i = 1:4
                StrandedAssetValue(generator,yr,i) = abs(((PowerPlantProfits(generator,yr))-(PowerPlantProfits_CarbonTax(generator,yr,i))))./((1 + DiscountRate).^yr);
            end
        end
    end 
    
    AnnualStrandedAssets = Present_Value_Stranded_Assets_based_on_added_costs;
    StrandedAssetValue = squeeze(nansum(Present_Value_Stranded_Assets_based_on_added_costs,2));
    
    
    CorporateOwners = unique(PowerPlant_StringInformation(:,1));
    CountryLocations = unique(PowerPlant_StringInformation(:,2));
    PowerPlantFinances_byCompany = zeros(length(CorporateOwners),max_Life,5);
    RevenuebyCompany = zeros(length(CorporateOwners),1);
    colorschemecategory = nan(length(CorporateOwners),length(colorschemecategoryFuel));
    StrandedAssetValuebyCompany = zeros(length(CorporateOwners),4);
    PresentAssetValuebyCompany = zeros(length(CorporateOwners),1);
    PowerPlantStrandedAssets_byCompany = zeros(length(CorporateOwners),max_Life,4);
    
    for generator = 1:length(PowerPlant_StringInformation)
        for Company = 1:length(CorporateOwners)
            if strcmpi(PowerPlant_StringInformation{generator,1},CorporateOwners{Company,1})
                for yr = 1:max_Life
                    PowerPlantFinances_byCompany(Company,yr,1) = PowerPlantFinances_byCompany(Company,yr,1) + PowerPlantProfits(generator,yr);
                    PowerPlantFinances_byCompany(Company,yr,2) = PowerPlantFinances_byCompany(Company,yr,2) + PowerPlantProfits_CarbonTax(generator,yr);
                    PowerPlantFinances_byCompany(Company,yr,3) = PowerPlantFinances_byCompany(Company,yr,3) + PresentAssetValue(generator,yr);
                    PowerPlantFinances_byCompany(Company,yr,4) = PowerPlantFinances_byCompany(Company,yr,4) + PresentAssetValue_Carbontax(generator,yr);
                    
                    PowerPlantStrandedAssets_byCompany(Company,yr,:) = PowerPlantStrandedAssets_byCompany(Company,yr,:) + AnnualStrandedAssets(generator,yr,:);
                end
                PresentAssetValuebyCompany(Company,:) = PresentAssetValuebyCompany(Company,:) + nansum(PresentAssetValue(generator,:),2);
                PowerPlantString_ByCompany(Company,:) = PowerPlant_StringInformation(generator,1);
                RevenuebyCompany(Company,1) = RevenuebyCompany(Company,1) + PowerPlantRevenue(generator);
                StrandedAssetValuebyCompany(Company,:) = StrandedAssetValuebyCompany(Company,:) + StrandedAssetValue(generator,:);
                PowerPlantFinances_byCompany(Company,1,5) = PowerPlantFinances_byCompany(Company,1,5) + StrandedAssetValue(generator,2);
                colorschemecategory(Company,generator) = colorschemecategoryFuel(generator);
            end
        end
    end
    
   TotalPowerPlantCapacitybyCompany = zeros(length(CorporateOwners),1);
   PowerPlantLife_byCompany = zeros(length(CorporateOwners),max_Life);
   
   Capacity = Plants(:,1);
    
    for generator = 1:length(Plants)
        for yr = 1:max_Life 
            PlantAge(generator,yr) =  Plants(generator,2)+yr;
        end
    end
    
    PlantAge(isnan(PlantAge)) = 0;
    
    for Company = 1:length(CorporateOwners)
        for generator = 1:length(PowerPlant_StringInformation)
            if strcmpi(PowerPlant_StringInformation{generator,1},CorporateOwners{Company,1})
                TotalPowerPlantCapacitybyCompany(Company,1) = TotalPowerPlantCapacitybyCompany(Company,1) + Capacity(generator,1)* (Plants(generator,5)/100);
            end
        end
    end
    
    for Company = 1:length(CorporateOwners)
        for generator = 1:length(PowerPlant_StringInformation)
            if strcmpi(PowerPlant_StringInformation{generator,1},CorporateOwners{Company,1})
                PowerPlantLife_byCompany(Company,:) = PowerPlantLife_byCompany(Company,:) + PlantAge(generator,:).*(Capacity(generator,1)./TotalPowerPlantCapacitybyCompany(Company))*(Plants(generator,5)/100);%plant age weighted by capacity and percent ownership
            end
        end
    end
    
    PowerPlantLife_byCompany = round(PowerPlantLife_byCompany);
    PowerPlantFinances_byCountry = zeros(length(CountryLocations),max_Life,5);
    RevenuebyCountry = zeros(length(CountryLocations),1);
    PowerPlantStrandedAssets_byCountry = zeros(length(CountryLocations),max_Life,4);
    
    for generator = 1:length(PowerPlant_StringInformation)
        for country = 1:length(CountryLocations)
            if strcmpi(PowerPlant_StringInformation{generator,2},CountryLocations{country,1})
                for yr = 1:max_Life
                    PowerPlantFinances_byCountry(country,yr,1) = PowerPlantFinances_byCountry(country,yr,1) + PowerPlantProfits(generator,yr);
                    PowerPlantFinances_byCountry(country,yr,2) = PowerPlantFinances_byCountry(country,yr,2) + PowerPlantProfits_CarbonTax(generator,yr);
                    PowerPlantFinances_byCountry(country,yr,3) = PowerPlantFinances_byCountry(country,yr,3) + PresentAssetValue(generator,yr);
                    PowerPlantFinances_byCountry(country,yr,4) = PowerPlantFinances_byCountry(country,yr,4) + PresentAssetValue_Carbontax(generator,yr);
                    
                    PowerPlantString_ByCountry(country,:) = PowerPlant_StringInformation(generator,2);
                    PowerPlantStrandedAssets_byCountry(country,yr,:) = PowerPlantStrandedAssets_byCountry(country,yr,:)+AnnualStrandedAssets(generator,yr,:);
                end
                RevenuebyCountry(country,1) = RevenuebyCountry(country,1) + PowerPlantRevenue(generator);
                PowerPlantFinances_byCountry(country,1,5) = PowerPlantFinances_byCountry(country,1,5) + StrandedAssetValue(generator,2);
            end
        end
    end
    
    colorschemecategory  = mode(colorschemecategory,2);
    colorschemecategory(colorschemecategory == 0) = 8;
    save(['../Data/Results/colorschemecategory' PowerPlantFuel{gentype} '2'],'colorschemecategory');

    if saveresults == 1
        save(['../Data/Results/PowerPlantFinances_byCompany_' PowerPlantFuel{gentype} ''],'PowerPlantFinances_byCompany','PowerPlantString_ByCompany','PowerPlantLife_byCompany','TotalPowerPlantCapacitybyCompany','PlantAge','AnnualStrandedAssets','PresentAssetValuebyCompany','StrandedAssetValuebyCompany','PowerPlantStrandedAssets_byCompany');
        save(['../Data/Results/PowerPlantFinances_byCountry_' PowerPlantFuel{gentype} ''],'PowerPlantFinances_byCountry','PowerPlantString_ByCountry','PowerPlantStrandedAssets_byCountry');
        save(['../Data/Results/' PowerPlantFuel{gentype} 'Revenue.mat'],'RevenuebyCountry','RevenuebyCompany')
    end
end
